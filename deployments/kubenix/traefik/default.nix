{ kubenix, ... }:
{
  imports = with kubenix.modules; [
    k8s
    submodules
    ./dashboard_service.nix
    ./ingress.nix
  ];

  submodules.imports = [
    ../lib/namespaced.nix
  ];
}

