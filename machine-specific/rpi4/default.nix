{ nixos-raspberrypi, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-4.base
    ./kernel.nix
    ./config.nix
    ./../sd-filesytem.nix
    raspberry-pi-4.display-vc4
  ];
}

