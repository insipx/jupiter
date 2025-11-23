{
  description = "flake for managing rpi homelab";

  inputs = {
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/develop";
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

  outputs = inputs@{ flake-parts, nixos-raspberrypi, colmena, nixos-anywhere, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (_:
      let
        homelabModules.default = { ... }: {
          imports = [ ./homelab ];
        };
      in
      {
        imports = [
          inputs.pkgs-by-name-for-flake-parts.flakeModule
        ];
        systems = import inputs.systems;
        perSystem = { pkgs, system, ... }: {
          # pkgsDirectory = ./deployments;
          _module.args = import nixos-raspberrypi.inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.ghostty.overlays.default inputs.jupiter-secrets.overlays.default ];
          };
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              nixos-anywhere.packages.${system}.default
              colmena.packages.${system}.colmena
            ];
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
