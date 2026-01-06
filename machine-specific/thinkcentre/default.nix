{ ... }: {
  imports = [
    ./filesystem.nix
  ];

  services.getty.autologinUser = "insipx";
}
