{
  description = "flake for managing rpi homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    systems.url = "github:nix-systems/default";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { nixpkgs, flake-parts, nixos-raspberrypi, colmena, disko, nixos-anywhere, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }:
      let
        flakeModules.default =  {pkgs, ...}: {
          imports = [ ./base_configuration ];
        # rpiHomeLab = withSystem pkgs.stdenv.hostPlatform.system ({ config, ... }: {
        #   networking = {
        #     inherit (config.rpiHomeLab.networking) hostId hostName address;
        #   };
        #   inherit (inputs) disko;
        # });
        };
      in {
      systems = import inputs.systems;
      perSystem = { pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            nixos-anywhere.packages.${system}.default
            colmena.packages.${system}.colmena
          ];
        };
      };
      flake = {
        inherit flakeModules;
        nixosConfiguration.rpi5-install = nixos-raspberrypi.lib.nixosSystemFull {
          modules = [ flakeModules.default ];
          rpiHomeLab = {
            networking = {
              hostId = "cb5cda31"; # this should be unique per-machine
            };
          };
          specialArgs = inputs;
        };
        colmenaHive = colmena.lib.makeHive {
          meta = {
            nixpkgs = import nixos-raspberrypi.inputs.nixpkgs {
              system = "x86_64-linux";
            };
            specialArgs = inputs;
          };
          defaults = _: {
            nixpkgs.system = "aarch64-linux";
            deployment = {
              tags = [ "homelab" ];
              targetUser = "insipx";
              buildOnTarget = false;
            };
            imports = [
              flakeModules.default
              nixos-raspberrypi.lib.inject-overlays
              ./base_configuration/modules
              inputs.disko.nixosModules.disko
              ./base_configuration/disko-nvme-zfs.nix
            ];
            rpiHomeLab.disko = inputs.disko;
          };
          ganymede = _: {
            deployment = {
              targetHost = "ganymede.jupiter.lan";
            };
            rpiHomeLab.networking = {
              hostId = "76fa8e01";
              hostName = "ganymede";
              address = "10.10.69.10";
            };
          };
          io = _: {
            deployment = {
              # targetHost = "io.jupter.lan": NO
              targetHost = "10.10.69.155";
            };
            rpiHomeLab.networking = {
              hostName = "io";
              hostId = "19454311";
              address = "10.10.69.11";
            };
          };
          europa = _: {
            deployment = {
                # targetHost = "europa.jupiter.lan"; NO
                targetHost = "10.10.69.152";
            };
            rpiHomeLab.networking = {
              hostId = "29af5daa";
              hostName = "europa";
              address = "10.10.69.12";
            };
          };
          callisto = _: {
            rpiHomeLab.networking = {
              hostId = "b0d6aebd";
              hostName = "callisto";
              address = "10.10.69.14";
            };
            deployment.targetHost = "10.10.69.14";
            # deployment.targetHost = "callisto.jupiter.lan";
          };
        };
      };
    });
}
