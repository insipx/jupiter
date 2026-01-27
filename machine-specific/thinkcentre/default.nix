{ pkgs, ... }: {
  imports = [
    ./../filesystem.nix
    ./boot.nix
  ];
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
  services.getty.autologinUser = "insipx";
}
