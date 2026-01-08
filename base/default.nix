{ disko, jupiter-secrets, nixos-raspberrypi, homelabModules, pkgs, ... }: {
  imports = [
    ./console.nix
    ./network.nix
    ./user.nix
    # nixos-raspberrypi.lib.inject-overlays
    # disko.nixosModules.disko
    # jupiter-secrets.nixosModules.default
    # homelabModules.default
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
    lshw
    ntp
    cryptsetup
    lvm2
    nfs-utils
    libnfs
  ];
  services.chrony = {
    enable = true;
    enableNTS = false; # not enabled in opnsense
    servers = [
      "lab_gateway.jupiter.lan"
    ];
  };
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
  rpiHomeLab = {
    k3s.leaderAddress = "https://ganymede.jupiter.lan:6443";
  };
  jupiter-secrets.enable = true;
}
