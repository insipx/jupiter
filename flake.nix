{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixos-raspberrypi.nixpkgs.follow = "nixpkgs";
    disko = {
      # the fork is needed for partition attributes support
      url = "github:nvmd/disko/gpt-attrs";
      # url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
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

  outputs = { self, nixpkgs, nixos-raspberrypi, disko }@inputs: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;
    rpi5 = nixos-raspberrypi.lib.nixosSystemFull {
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
}
