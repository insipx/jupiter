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
        argocd-image-updater = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://argoproj.github.io/argo-helm";
            chart = "argocd-image-updater";
            version = "1.3.1";
            sha256 = "sha256-ShJpGAHqMDvX6i3wLIExxcuHD1/uEqKgDG+x0brZtzk=";
          };
          namespace = ns;
          values = {
            config.argocd = {
              serverAddress = "https://argocd.${flake.lib.hostname}";
              # argocd-server runs plaintext behind traefik (server.insecure),
              # so the updater must not negotiate TLS against it.
              insecure = true;
              plaintext = true;
            };
          };
        };
        argocd = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://argoproj.github.io/argo-helm";
            chart = "argo-cd";
            version = "10.9.2";
            sha256 = "sha256-JAX+7mD24r5bn566BSxAnBYwh2DsF1Cr+pn5eDYSUjQ=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            crds.install = false;
            configs.secret.createSecret = false;
            configs.params."server.insecure" = true;
            controller.metrics.serviceMonitor.enabled = true;
            global.domain = "argocd.${flake.lib.hostname}";

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
          # Used by image-updater to push the new image tag back to the
          # manifest repo. Needs `contents: write`; the notifications app only
          # needs checks/statuses, so confirm the permission before reusing it.
          git-creds = {
            metadata = {
              name = "git-creds";
              namespace = ns;
            };
            stringData = {
              githubAppID = "4924749";
              githubAppInstallationID = "161237440";
              githubAppPrivateKey = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/argo_git_app_private_key";
            };
          };
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
        imageupdater.website = {
          metadata = {
            name = "website";
            namespace = ns;
          };
          spec = {
            # also could be git to commit new image to git
            writeBackConfig.method = "argocd";
            applicationRefs = [
              {
                namePattern = "insipx";
                images = [
                  {
                    alias = "web";
                    imageName = "ghcr.io/insipx/website";
                    commonUpdateSettings = {
                      updateStrategy = "newest-build";
                      allowTags = "regexp:^[0-9a-f]{40}$";
                    };
                  }
                ];
              }
            ];
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
        imageupdater = {
          attrName = "imageupdater";
          group = "argocd-image-updater.argoproj.io";
          version = "v1alpha1";
          kind = "ImageUpdater";
        };
      };
    };
  };
}
