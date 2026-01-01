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
    # kubenix.url = "github:sheepforce/kubenix/helm-proxy"; # Includes patch to fetch helm charts with a forward proxy
    kubenix.url = "github:hall/kubenix";
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
            extra = _: prev: {
              writeFishScriptBin = pkgs.callPackage ./scripts/write_fish_script { };
            };
            kubenixPkg = inputs'.kubenix.packages.default.override {
              module = import ./deployments/kubenix/default.nix;
              specialArgs = { flake = self; };
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
                pkgs.kubernetes-helm
              ];
            };
            packages = {
              kubenix = kubenixPkg;
            };
          };
        flake =
          {
            inherit homelabModules;
            lib = {
              hostname = "jupiter.lan";
            };
            nixosConfigurations.rpi5Install = nixos-raspberrypi.lib.nixosSystemFull {
              modules = [
                homelabModules.default
                inputs.disko.nixosModules.disko
                {
                  rpiHomeLab = {
                    networking = {
                      hostId = "c3adcefb"; # this should be unique per-machine
                      hostName = "tinyca"; # change before installing
                      address = "10.10.69.18/24"; # change before installing
                      interface = "end0";
                    };
                    k3s.enable = false;
                  };
                  imports = [
                    ./base
                    ./machine-specific/tinyca
                    # ./machine-specific/rpi5
                    # ./machine-specific/rpi4
                    # ./machine-specific/rpi3
                  ];
                }
              ];
              specialArgs = inputs;
            };
            colmenaHive = import ./hive { inherit inputs homelabModules; };
          };
      });
}
