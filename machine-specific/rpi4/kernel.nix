{ pkgs, ... }:
let
  kernelBundle = pkgs.linuxAndFirmware.default;
in
{
  boot = {
    loader.raspberryPi = {
      variant = "4";
      bootloader = "kernel";
      firmwarePackage = kernelBundle.raspberrypifw;
    };
    kernelPackages = kernelBundle.linuxPackages_rpi4;
    initrd.availableKernelModules = [
      "nvme" # cm4 may have nvme drive connected with pcie
    ];
  };
}
