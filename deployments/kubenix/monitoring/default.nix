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
    ./alloy.nix
    ./opnsense-exporter.nix
    ./kube-stack.nix
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
  };
}

