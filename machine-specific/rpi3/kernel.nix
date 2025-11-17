# no override for rpi4 yet
{ pkgs, ... }:
let
  kernelBundle = pkgs.linuxAndFirmware.default;
in
{
  boot = {
    loader.raspberryPi = {
      variant = "3";
      bootloader = "kernel";
      firmwarePackage = kernelBundle.raspberrypifw;
    };
    kernelPackages = kernelBundle.linuxPackages_rpi3;
    kernelParams = [
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];
  };
}
