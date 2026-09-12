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
            version = "v10.9.0";
            sha256 = "sha256-JAX+7mD24r5bn566BSxAnBYwh2DsF1Cr+pn5eDYSUjQ=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            crds.install = false;
            configs.secret.createSecret = false;
            controller.metrics.serviceMonitor.enabled = true;
          };
        };
      };
      resources = {
        secrets = {
          argocd-secret = {
            metadata = {
              name = "argocd-secret";
              namespace = ns;
            };
            stringData = {
              "admin.password" = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/argo_admin_pass";
            };
          };
        };
        ingressroute.argo-cd = {
          metadata.namespace = ns;
          metadata.name = "argo-cd";
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`argocd.${flake.lib.hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = "argocd-server";
                    port = 80;
                  }
                ];
              }
            ];
            tls = { };
          };
        };
      };
      customTypes = {
        ingressroute = {
          attrName = "ingressroute";
          group = "traefik.io";
          version = "v1alpha1";
          kind = "IngressRoute";
        };
      };
    };
  };
}
