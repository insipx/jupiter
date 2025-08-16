{
  description = "A very basic flake";

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
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { flake-parts, nixos-raspberrypi, disko, nixos-anywhere, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      perSystem = { pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            nixos-anywhere.packages.${system}.default
          ];
        };
      };
      flake = {
        nixosConfigurations.rpi5 = nixos-raspberrypi.lib.nixosSystemFull {
          specialArgs = inputs;
          modules = [
            {
              networking.hostName = "ganymede";
            }
            ./modules/config.nix # main configuration
            # Disk configuration
            disko.nixosModules.disko
            # WARNING: formatting disk with disko is DESTRUCTIVE, check if
            # `disko.devices.disk.nvme0.device` is set correctly!
            ./disko-nvme-zfs.nix
            { networking.hostId = "8821e309"; } # NOTE: for zfs, must be unique
            # Further user configuration
            # common-user-config
            {
              boot.tmp.useTmpfs = true;
            }
          ];
        };
      };
    };
}
