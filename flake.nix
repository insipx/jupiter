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
    systems.url = "github:nix-systems/default";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
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
        systems = import inputs.systems;
        perSystem = { pkgs, system, ... }: {
          _module.args = import nixos-raspberrypi.inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.ghostty.overlays.default ];
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
                # inputs.sops-nix.nixosModules.sops
                nixos-raspberrypi.lib.inject-overlays-global # CAUSES REBUILDS (same as nixosSystemFull)
                nixos-raspberrypi.nixosModules.trusted-nix-caches
                nixos-raspberrypi.nixosModules.nixpkgs-rpi
                {
                  rpiHomeLab = {
                    networking = {
                      hostId = "00000000"; # this should be unique per-machine
                      hostName = "nixos-host";
                      address = "0.0.0.0/24";
                    };
                    secrets.enable = false;
                    k3s.enable = false;
                  };
                  imports = [
                    ./base_configuration/modules
                    ./base_configuration/disko-nvme-zfs.nix
                  ];
                }
                ({ lib, ... }: {
                  nixpkgs.overlays = lib.mkAfter [ piOverride ];
                })
              ];
              specialArgs = inputs;
            };
            colmenaHive = colmena.lib.makeHive
              {
                meta = {
                  nixpkgs = import nixos-raspberrypi.inputs.nixpkgs {
                    system = "aarch64-linux";
                    overlays = [
                      # inputs.ghostty.overlays.default
                      piOverride
                      #  (_: prev: {
                      #    nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystemFull;
                      #  })
                    ];
                  };
                  specialArgs = inputs;
                };
                defaults = _: {
                  deployment = {
                    tags = [ "homelab" ];
                    targetUser = "insipx";
                    buildOnTarget = false;
                  };
                  imports = [
                    homelabModules.default
                    nixos-raspberrypi.lib.inject-overlays
                    inputs.disko.nixosModules.disko
                    inputs.sops-nix.nixosModules.sops
                    ./base_configuration/modules
                    ./base_configuration/disko-nvme-zfs.nix
                  ];
                  rpiHomeLab = {
                    k3s.enable = false;
                    secrets.enable = true;
                  };
                };
                ganymede = _: {
                  deployment = {
                    targetHost = "ganymede.jupiter.lan";
                  };
                  rpiHomeLab = {
                    networking = {
                      hostId = "445ba108";
                      hostName = "ganymede";
                      address = "10.10.69.10/24";
                    };
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
