{ inputs, ... }: {
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    ./kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    ./config.nix
    ./filesystem.nix
  ];
  # Automatically log in at the virtual consoles.
  services.getty.autologinUser = "insipx";
}

