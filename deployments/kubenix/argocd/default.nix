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
            configs.params."server.insecure" = true;
            controller.metrics.serviceMonitor.enabled = true;

            notifications = {
              secret.create = false;
              notifiers = {
                "service.github" = ''
                  appID: 4924749
                  installationID: 161237440
                  privateKey: $github-privateKey
                '';
              };
              subscriptions = [
                {
                  recipients = [ "github" ];
                  triggers = [
                    # "on-sync-succeeded"
                    # "on-sync-failed"
                    "on-deployed"
                  ];
                }
              ];
              templates."template.app-deployed" = builtins.readFile ./app-deployed.yaml;

              triggers."trigger.on-deployed" = ''
                - description: Application is synced and healthy
                  send:
                  - app-deployed
                  when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
              '';
            };
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
          argocd-notifications-secret = {
            metadata = {
              name = "argocd-notifications-secret";
              namespace = ns;
            };
            stringData = {
              github-privateKey = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/argo_git_app_private_key";
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
                priority = 10;
                services = [
                  {
                    name = "argocd-server";
                    port = 80;
                  }
                ];
              }
              # https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#ingressroute-crd
              {
                match = "Host(`argocd.${flake.lib.hostname}`) && Header(`Content-Type`, `application/grpc`)";
                kind = "Rule";
                priority = 11;
                services = [
                  {
                    name = "argocd-server";
                    port = 80;
                    scheme = "h2c";
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
