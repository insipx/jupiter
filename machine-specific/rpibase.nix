{ nixos-raspberrypi
, pkgs
, ...
}: {
  imports = [
    nixos-raspberrypi.lib.inject-overlays

  ];

  environment.systemPackages = with pkgs; [
    raspberrypi-eeprom
    raspberrypi-udev-rules
    raspberrypi-utils
  ];
}
