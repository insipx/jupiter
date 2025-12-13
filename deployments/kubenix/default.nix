{ kubenix, ... }:

{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
    ./longhorn/default.nix
    # ./rbd-hdd-csi/default.nix
    # And all others you would like to import
  ];

  submodules.imports = [
    ./lib/namespaced.nix
  ];
}
