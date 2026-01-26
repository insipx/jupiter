{ kubenix, ... }:
let
  ns = "monitoring";

in
{
  imports = with kubenix.modules; [
    k8s
    docker
    submodules
    helm
    ./opnsense-exporter.nix
    ./kube-stack.nix
    ./alloy.nix
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
  };
}

