{ kubenix, flake, ... }:
let
  ns = "personal-apps";
  app = "wealthfolio";
  # https://wealthfolio.app/docs/guide/self-hosting/
  # No Helm chart upstream, so deploy raw Deployment + Service + PVC.
  image = "wealthfolio/wealthfolio:3.7.0";
  port = 8088;
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes = {
      resources = {
        # Secrets that back WF_SECRET_KEY / WF_AUTH_PASSWORD_HASH.
        # Generate and store in sops before deploying:
        #   WF_SECRET_KEY:        openssl rand -base64 32
        #   WF_AUTH_PASSWORD_HASH: argon2id PHC hash (use printf, not echo)
        secrets.wealthfolio = {
          metadata.name = "wealthfolio";
          metadata.namespace = ns;
          stringData = {
            secret-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/wealthfolio_secret_key";
            password-hash = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/wealthfolio_password_hash";
          };
        };

        # Persistent SQLite database lives at /data (WF_DB_PATH).
        persistentvolumeclaims.wealthfolio = {
          metadata.name = "wealthfolio-data";
          metadata.namespace = ns;
          spec = {
            accessModes = [ "ReadWriteOnce" ];
            storageClassName = "longhorn-static";
            resources.requests.storage = "5Gi";
          };
        };

        deployments.${app} = {
          metadata.labels.app = app;
          metadata.namespace = ns;
          spec = {
            replicas = 1;
            selector.matchLabels.app = app;
            # RWO volume can't attach to two pods: RollingUpdate deadlocks on
            # Multi-Attach, new pod stuck ContainerCreating until old one dies.
            strategy.type = "Recreate";
            template = {
              metadata.labels.app = app;
              spec = {
                containers.${app} = {
                  name = app;
                  inherit image;
                  imagePullPolicy = "IfNotPresent";
                  env = [
                    {
                      name = "WF_LISTEN_ADDR";
                      value = "0.0.0.0:${toString port}";
                    }
                    {
                      name = "WF_DB_PATH";
                      value = "/data/wealthfolio.db";
                    }
                    {
                      name = "WF_CORS_ALLOW_ORIGINS";
                      value = "https://${app}.${flake.lib.hostname},https://${app}.${flake.lib.external-hostname}";
                    }
                    {
                      name = "WF_SECRET_KEY";
                      valueFrom.secretKeyRef = {
                        name = "wealthfolio";
                        key = "secret-key";
                      };
                    }
                    {
                      name = "WF_AUTH_PASSWORD_HASH";
                      valueFrom.secretKeyRef = {
                        name = "wealthfolio";
                        key = "password-hash";
                      };
                    }
                  ];
                  ports."http" = {
                    containerPort = port;
                    protocol = "TCP";
                  };
                  volumeMounts = [
                    {
                      name = "data";
                      mountPath = "/data";
                    }
                  ];
                };
                volumes = [
                  {
                    name = "data";
                    persistentVolumeClaim.claimName = "wealthfolio-data";
                  }
                ];
              };
            };
          };
        };

        services.${app} = {
          metadata.namespace = ns;
          spec = {
            selector.app = app;
            ports = [
              {
                name = "http";
                inherit port;
                targetPort = port;
              }
            ];
            type = "ClusterIP";
          };
        };

        # Internal IngressRoute - accessible from jupiter.lan network without client cert
        ingressroute.wealthfolio = {
          metadata.namespace = ns;
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`${app}.${flake.lib.hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = app;
                    inherit port;
                  }
                ];
              }
            ];
            tls = { };
          };
        };
        # External IngressRoute - accessible via Rathole with mTLS (client cert required)
        # Rathole on Fly.io should forward to 10.10.68.1:8443
        # Client certificates can be generated using: step ca certificate user@jupiter.lan user.crt user.key
        ingressroute.wealthfolio-external = {
          metadata = {
            name = "wealthfolio-external";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "websecure-external" ];
            routes = [
              {
                match = "Host(`${app}.${flake.lib.hostname}`) || Host(`${app}.${flake.lib.external-hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = app;
                    inherit port;
                  }
                ];
              }
            ];
            tls = { };
            # tls.options.name = "mtls-required";
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
