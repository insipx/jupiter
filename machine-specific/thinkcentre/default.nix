{ ... }: {
  imports = [
    ./../filesystem.nix
    ./boot.nix
  ];

  services.getty.autologinUser = "insipx";
}
