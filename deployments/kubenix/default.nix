{ kubenix, ... }:

{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
    ./longhorn/default.nix
    ./monitoring/default.nix
    ./traefik/default.nix
    ./metal-lb/default.nix
    ./certs
    ./personal-apps
    ./website
    ./argocd
    # ./pihole
  ];

  submodules.imports = [
    ./lib/namespaced.nix
  ];
}
