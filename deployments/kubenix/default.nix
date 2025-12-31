{ kubenix, ... }:

{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
    # ./longhorn/default.nix
    # ./monitoring/default.nix
    # ./traefik/default.nix
    ./metal-lb/default.nix
  ];

  submodules.imports = [
    ./lib/namespaced.nix
  ];
}
