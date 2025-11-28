{
  description = "flake for managing rpi homelab";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
    disko = {
      # the fork is needed for partition attributes support
      url = "github:nvmd/disko/gpt-attrs";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      # flake parts does not use nixpkgs
      # inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
    systems.url = "github:nix-systems/default";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    jupiter-secrets = {
      url = "git+ssh://git@github.com/insipx/jupiter-secrets";
      # url = "path:/Users/andrewplaza/code/insipx/jupiter-secrets";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
      inputs.sops-nix.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    kubenix.url = "github:hall/kubenix";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
    ];
  };

  outputs = inputs@{ flake-parts, nixos-raspberrypi, kubenix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (_:
      let
        homelabModules.default = { ... }: {
          imports = [ ./homelab ];
        };
      in
      {
        imports = [
          ./scripts
          inputs.pkgs-by-name-for-flake-parts.flakeModule
          inputs.flake-parts.flakeModules.easyOverlay
        ];
        systems = import inputs.systems;
        perSystem = { pkgs, self, self', system, inputs', ... }:
          let
            pkgs-firefox = import inputs.chaotic-nixpkgs {
              inherit system;
              overlays = [ inputs.chaotic.overlays.default ];
            };
            extra = _: prev: {
              inherit (pkgs-firefox) firefox_nighty;
              writeFishScriptBin = pkgs.callPackage ./scripts/write_fish_script { };
            };
          in
          {
            # pkgsDirectory = ./deployments;
            _module.args = import nixos-raspberrypi.inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.ghostty.overlays.default inputs.jupiter-secrets.overlays.default extra ];
            };
            devShells.default = pkgs.mkShell {
              nativeBuildInputs = [
                inputs'.nixos-anywhere.packages.default
                inputs'.colmena.packages.colmena
                self'.packages.kubenix
                self'.packages.build_session
                self'.packages.launch_instance_on_demand
                self'.packages.launch_instance
              ];
            };
            packages =
              let
                prometheus = (kubenix.evalModules.${system} {
                  module = _: {
                    imports = [ ./deployments/prometheus.nix ];
                  };
                }).config;
              in
              {
                prometheusDeployment = prometheus.kubernetes.result;
                prometheusImage = prometheus.docker.images.prometheus-monitoring.image;
                kubenix = inputs'.kubenix.packages.default.override {
                  module = import ./deployments/prometheus.nix;
                  # optional; pass custom values to the kubenix module
                  specialArgs = { flake = self; };
                };
              };
          };
        flake =
          let
            piOverride = _: prev: {
              sdl3 = (prev.sdl3.override { testSupport = false; }).overrideAttrs { doCheck = false; };
            };
          in
          {
            inherit homelabModules;
            nixosConfigurations.rpi5Install = nixos-raspberrypi.lib.nixosSystem {
              modules = [
                homelabModules.default
                inputs.disko.nixosModules.disko
                nixos-raspberrypi.lib.inject-overlays-global # CAUSES REBUILDS (same as nixosSystemFull)
                nixos-raspberrypi.nixosModules.trusted-nix-caches
                nixos-raspberrypi.nixosModules.nixpkgs-rpi
                {
                  rpiHomeLab = {
                    networking = {
                      hostId = "00000000"; # this should be unique per-machine
                      hostName = "generic-nixos-host"; # change before installing
                      address = "0.0.0.0/24"; # change before installing
                    };
                    k3s.enable = false;
                  };
                  imports = [
                    ./base
                    ./machine-specific/rpi5
                    # ./machine-specific/rpi4
                    # ./machine-specific/rpi3
                  ];
                }
                ({ lib, ... }: {
                  nixpkgs.overlays = lib.mkAfter [ piOverride ];
                })
              ];
              specialArgs = inputs;
            };
            colmenaHive = import ./hive { inherit inputs homelabModules; };
          };
      });
}
