{ kubenix, ... }:
let
  ns = "website";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  # Owns only the namespace. Everything inside it -- workload, service,
  # external IngressRoute, and the NetworkPolicies that contain it -- is
  # managed by Argo CD from the site's own repo, so the app describes its
  # own requirements in a single place.
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes = { };
  };
}
