{ pkgs, ... }: {
  imports = [
    ./console.nix
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
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };
}
