{ nixos-raspberrypi, config, pkgs, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    # Hardware configuration
    raspberry-pi-5.base
    raspberry-pi-5.display-vc4
    ./pi5-configtxt.nix
    ./pretty_console.nix
    ./user.nix
    ./network.nix
    ./config.nix
  ];

  time.timeZone = "UTC";
  services.udev.extraRules = ''
    # Ignore partitions with "Required Partition" GPT partition attribute
    # On our RPis this is firmware (/boot/firmware) partition
    ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
      ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
      ENV{UDISKS_IGNORE}="1"
  '';

  environment.systemPackages = with pkgs; [
    tree
  ];

  system.nixos.tags =
    let
      cfg = config.boot.loader.raspberryPi;
    in
    [
      "raspberry-pi-${cfg.variant}"
      cfg.bootloader
      config.boot.kernelPackages.kernel.version
    ];
}
