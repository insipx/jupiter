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
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixpkgs";
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { flake-parts, nixos-raspberrypi, colmena, nixos-anywhere, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (_:
      let
        homelabModules.default = { ... }: {
          imports = [ ./homelab ];
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
              inputs.sops-nix.nixosModules.sops
              {
                rpiHomeLab = {
                  networking = {
                    hostId = "00000000"; # this should be unique per-machine
                    hostName = "nixos-anywhere-placeholder";
                    address = "10.10.69.69";
                  };
                };
                imports = [
                  ./base_configuration/modules
                  ./base_configuration/disko-nvme-zfs.nix
                ];
              }
            ];
            specialArgs = inputs;
          };
          colmenaHive = colmena.lib.makeHive {
            meta = {
              nixpkgs = import nixos-raspberrypi.inputs.nixpkgs {
                system = "x86_64-linux";
                overlays = [ inputs.ghostty.overlays.default ];
              };
              # nodeNixpkgs = import nixos-raspberrypi.inputs.nixpkgs { system = "aarch64-linux"; };
              specialArgs = inputs;
            };
            defaults = _: {
              nixpkgs.system = "aarch64-linux";
              deployment = {
                tags = [ "homelab" ];
                targetUser = "insipx";
                buildOnTarget = true;
              };
              imports = with nixos-raspberrypi.nixosModules; [
                homelabModules.default
                nixos-raspberrypi.lib.inject-overlays
                inputs.disko.nixosModules.disko
                inputs.sops-nix.nixosModules.sops
                ./base_configuration/modules
                ./base_configuration/disko-nvme-zfs.nix
              ];
              rpiHomeLab.k3s.enable = false;
            };
            ganymede = _: {
              deployment = {
                targetHost = "ganymede.jupiter.lan";
              };
              rpiHomeLab.networking = {
                hostId = "76fa8e01";
                hostName = "ganymede";
                address = "10.10.69.10/24";
              };
              rpiHomeLab.k3s.leader = true;
            };
            io = _: {
              deployment = {
                targetHost = "io.jupiter.lan";
              };
              rpiHomeLab.networking = {
                hostName = "io";
                hostId = "19454311";
                address = "10.10.69.11/24";
              };
              rpiHomeLab.k3s = {
                leaderAddress = "10.10.69.10";
              };
            };
            europa = _: {
              deployment = {
                targetHost = "europa.jupiter.lan";
              };
              rpiHomeLab.networking = {
                hostId = "29af5daa";
                hostName = "europa";
                address = "10.10.69.12/24";
              };
              rpiHomeLab.k3s = {
                leaderAddress = "10.10.69.10";
              };
            };
            callisto = _: {
              rpiHomeLab.networking = {
                hostId = "b0d6aebd";
                hostName = "callisto";
                address = "10.10.69.14/24";
              };
              rpiHomeLab.k3s = {
                leaderAddress = "10.10.69.10";
              };
              deployment.targetHost = "10.10.69.14";
            };
          };
        };
      });
}
