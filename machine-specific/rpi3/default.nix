{ nixos-raspberrypi, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-3.base
    ./kernel.nix
    ./config.nix
    ./../sd-filesystem.nix
  ];
}
