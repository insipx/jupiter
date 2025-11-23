{ nixos-raspberrypi, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-3.base
    ./kernel.nix
    ./config.nix
    ./../sd-filesystem.nix
  ];
  # Automatically log in at the virtual consoles.
  services.getty.autologinUser = "insipx";
}
