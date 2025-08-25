{ nixos-raspberrypi, pkgs, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    # Hardware configuration
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4
    ./pi5_configtxt.nix
    ./pretty_console.nix
    ./user.nix
    ./network.nix
    ./server-config.nix
  ];

  time.timeZone = "America/New_York";
  services.udev.extraRules = ''
    # Ignore partitions with "Required Partition" GPT partition attribute
    # On our RPis this is firmware (/boot/firmware) partition
    ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
      ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
      ENV{UDISKS_IGNORE}="1"
  '';

  environment.systemPackages = with pkgs; [
    tree
    raspberrypi-eeprom
    neovim
    htop
    ghostty.terminfo
  ];
  environment.enableAllTerminfo = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
