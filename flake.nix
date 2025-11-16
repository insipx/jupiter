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
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    jupiter-secrets = {
      # url = "git+ssh://git@github.com/insipx/jupiter-secrets";
      url = "path:/Users/andrewplaza/code/insipx/jupiter-secrets";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
      inputs.sops-nix.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
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
                    jupiter-secrets.enable = false;
                  };
                  imports = [
                    ./base
                    # ./machine-specific/rpi5
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
                    # targetUser = "insipx";
                    buildOnTarget = true;
                  };
                  imports = [
                    homelabModules.default
                    nixos-raspberrypi.lib.inject-overlays
                    inputs.disko.nixosModules.disko
                    inputs.jupiter-secrets.nixosModules.default
                    ./base
                  ];
                  rpiHomeLab = {
                    k3s.enable = true;
                    k3s.leaderAddress = "https://ganymede.jupiter.lan:6443";
                  };
                  jupiter-secrets.enable = true;
                };
                ganymede = _: {
                  imports = [
                    ./machine-specific/rpi5
                  ];
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
                  services.k3s.extraFlags = [
                    "--tls-san ganymede.jupiter.lan"
                    "--tls-san ganymede"
                    "--tls-san 10.10.69.10"
                  ];
                };
                io = _: {
                  deployment = {
                    targetHost = "io.jupiter.lan";
                    tags = [ "workers" ];
                  };
                  rpiHomeLab.networking = {
                    hostName = "io";
                    hostId = "19454311";
                    address = "10.10.69.11/24";
                  };
                };
                europa = _: {
                  imports = [
                    ./machine-specific/rpi5
                  ];
                  deployment = {
                    tags = [ "workers" ];
                    targetHost = "europa.jupiter.lan";
                  };
                  rpiHomeLab.networking = {
                    hostId = "29af5daa";
                    hostName = "europa";
                    address = "10.10.69.12/24";
                  };
                };
                callisto = _: {
                  imports = [
                    ./machine-specific/rpi5
                  ];
                  deployment = {
                    tags = [ "workers" ];
                    targetHost = "callisto.jupiter.lan";
                  };
                  rpiHomeLab.networking = {
                    hostId = "b0d6aebd";
                    hostName = "callisto";
                    address = "10.10.69.14/24";
                  };
                  # callisto is the only node which is a worker
                  rpiHomeLab.k3s.agent = true;
                };
                amalthea = _: {
                  imports = [
                    ./machine-specific/rpi4
                  ];
                  deployment = {
                    tags = [ "workers" ];
                    targetHost = "amalthea.jupiter.lan";
                  };
                  rpiHomeLab.networking = {
                    hostId = "0de35cfb";
                    hostName = "amalthea";
                    address = "10.10.69.15/24";
                  };
                  # callisto is the only node which is a worker
                  rpiHomeLab.k3s.agent = true;
                };
                sinope = _: {
                  imports = [
                    ./machine-specific/rpi3
                  ];
                  deployment = {
                    tags = [ "workers" ];
                    targetHost = "sinope.jupiter.lan";
                    targetUser = "nixos";
                  };
                  rpiHomeLab.networking = {
                    hostId = "0c461a51";
                    hostName = "sinope";
                    address = "10.10.69.16/24";
                  };
                  # callisto is the only node which is a worker
                  rpiHomeLab.k3s.agent = true;
                };
              };
          };
      });
}
