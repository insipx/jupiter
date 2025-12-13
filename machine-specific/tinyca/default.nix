{ inputs, pkgs, ... }: {
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    ./../rpi5/kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    ./../rpi5/config.nix
    ./../rpi5/filesystem.nix
  ];
  # Automatically log in at the virtual consoles.
  environment.systemPackages = with pkgs; [
    yubikey-manager
    go
    step-ca
    step-cli
    infnoise
    e2fsprogs
  ];
  services = {
    getty.autologinUser = "insipx";
    infnoise.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
  };
}

