{ kubenix, flake, ... }:
let
  ns = "argocd";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.argocd = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        argocd = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://argoproj.github.io/argo-helm";
            chart = "argo-cd";
            version = "v3.21.0";
            sha256 = "sha256-0000000000000000000000000000000000000000000=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            configs.secrets = {
              argocdServerAdminPassword = "argo-admin-pass";
            };
          };
        };
      };
      resources = {
        secrets = {
          argo-admin-pass = {
            metadata = {
              name = "argo-admin-pass";
              namespace = ns;
            };
            stringData = {
              argo-admin-pass = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/argo_admin_pass";
            };
          };
        };
      };
    };
  };
}
