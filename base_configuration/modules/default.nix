{ nixos-raspberrypi, pkgs, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    # Hardware configuration
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    nixpkgs-rpi
    trusted-nix-caches
    nixos-raspberrypi.lib.inject-overlays-global
    ./configtxt.nix
    ./pretty-console.nix
    ./user.nix
    ./network.nix
  ];

  time.timeZone = "America/New_York";
  environment.systemPackages = with pkgs; [
    tree
    raspberrypi-eeprom
    neovim
    htop
    ghostty.terminfo
    powertop
    sops
    efibootmgr
    cowsay
    raspberrypi-udev-rules
    raspberrypi-utils
  ];
  environment.enableAllTerminfo = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  boot.loader.raspberryPi.bootloader = "kernel";
}
