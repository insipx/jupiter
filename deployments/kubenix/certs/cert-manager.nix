{ kubenix, ... }:
let
  ns = "cert-manager";
in
{
  imports = with kubenix.modules; [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.cert-manager = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        cert-manager = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://charts.jetstack.io";
            chart = "cert-manager";
            version = "v1.19.2";
            sha256 = "sha256-0000000000000000000000000000000000000000000=";
          };
          includeCRDs = true;
          namespace = ns;
        };
      };
    };
  };
}
