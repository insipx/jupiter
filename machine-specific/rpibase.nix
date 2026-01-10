{ nixos-raspberrypi
, pkgs
, ...
}: {
  nixpkgs.system = "aarch64-linux";
  imports = [
    nixos-raspberrypi.lib.inject-overlays

  ];

  environment.systemPackages = with pkgs; [
    raspberrypi-eeprom
    raspberrypi-udev-rules
    raspberrypi-utils
  ];
}
