{ nixos-raspberrypi, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    ./kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.bluetooth
    ./config.nix
    ./filesystem.nix
  ];
}

