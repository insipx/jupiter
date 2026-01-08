{ kubenix, ... }:
let
  ns = "step-issuer";
in
{
  imports = with kubenix.modules; [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.cert-manager = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        step-issuer = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://smallstep.github.io/helm-charts";
            chart = "step-issuer";
            version = "v1.9.11";
            sha256 = "sha256-0000000000000000000000000000000000000000000=";
          };
          includeCRDs = true;
          namespace = ns;
        };
      };
    };
  };
}
