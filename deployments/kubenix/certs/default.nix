{ kubenix, ... }: {

  imports = with kubenix.modules; [
    k8s
    helm
    submodules
    ./cert-manager.nix
    ./step-issuer.nix
  ];

  submodules.imports = [
    ../lib/namespaced.nix
  ];
}
