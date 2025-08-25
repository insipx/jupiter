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
        homelabModules.default = { ... }: {
          imports = [ ./base_configuration ];
        };
      in
      {
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
          inherit homelabModules;
          nixosConfigurations.rpi5Install = nixos-raspberrypi.lib.nixosSystem {
            modules = [
              homelabModules.default
              inputs.disko.nixosModules.disko
              {
                rpiHomeLab = {
                  networking = {
                    hostId = "11111111"; # this should be unique per-machine
                    hostName = "initial-deploy-1";
                  };
                };
              }
            ];
            specialArgs = inputs;
          };
          colmenaHive = colmena.lib.makeHive {
            meta = {
              nixpkgs = import nixos-raspberrypi.inputs.nixpkgs {
                system = "x86_64-linux";
              };
              # nodeNixpkgs = import nixos-raspberrypi.inputs.nixpkgs { system = "aarch64-linux"; };
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
                homelabModules.default
                nixos-raspberrypi.lib.inject-overlays
                inputs.disko.nixosModules.disko
              ];
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
                targetHost = "io.jupiter.lan";
              };
              rpiHomeLab.networking = {
                hostName = "io";
                hostId = "19454311";
                address = "10.10.69.11";
              };
            };
            europa = _: {
              deployment = {
                targetHost = "europa.jupiter.lan";
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
              deployment.targetHost = "callisto.jupiter.lan";
            };
          };
        };
      });
}
