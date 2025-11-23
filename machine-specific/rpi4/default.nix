{ nixos-raspberrypi, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-4.base
    ./kernel.nix
    ./config.nix
    ./../sd-filesystem.nix
    raspberry-pi-4.display-vc4
  ];
  # Automatically log in at the virtual consoles.
  services.getty.autologinUser = "insipx";
}

