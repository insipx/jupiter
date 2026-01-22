{ inputs
, pkgs
, ...
}: {
  nixpkgs.system = "aarch64-linux";
  imports = [
    inputs.nixos-raspberrypi.lib.inject-overlays-global

  ];

  environment.systemPackages = with pkgs; [
    raspberrypi-eeprom
    raspberrypi-udev-rules
    raspberrypi-utils
  ];
  boot.blacklistedKernelModules = [ "vc4" ];
  boot.kernelModules = [ "vc4" "dm_crypt" ];
  systemd.services.modprobe-vc4 = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    before = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    script = "/run/current-system/sw/bin/modprobe vc4";
  };
}
