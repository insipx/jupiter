{ inputs, pkgs, ... }:
{
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    ./../rpi5/kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    ./../rpi5/config.nix
    ./../filesystem.nix
    ./../rpibase.nix
  ];
  environment.systemPackages = with pkgs; [
    net-tools
  ];

  services = {
    getty.autologinUser = "insipx";
  };
}
