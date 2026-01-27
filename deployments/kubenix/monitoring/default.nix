{ kubenix, lib, flake, ... }:
let
  ns = "monitoring";

  alloy = import ./alloy.nix { inherit flake; };
  opnsense-exporter = import ./opnsense-exporter.nix { inherit flake; };
in
{
  imports = with kubenix.modules; [
    k8s
    docker
    submodules
    helm
    ./kube-stack.nix
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes.resources = lib.recursiveUpdate alloy opnsense-exporter;
  };
}

