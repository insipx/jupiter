{ kubenix, flake, ... }:
let
  ns = "longhorn-system";
in
{
  imports = with kubenix.modules;
    [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.longhorn-system = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        longhorn = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://charts.longhorn.io";
            chart = "longhorn";
            version = "1.11.0";
            sha256 = "sha256-nkS4nvFK+K7J/sE+OxOPY0nR3lkrQF5K7JM5zbXLJ0s=";
          };
          noHooks = true;
          namespace = ns;
          values = {
            persistence = {
              defaultClass = true;
            };

            metrics.serviceMonitor = {
              enabled = true;
            };

            longhornUI.replicas = 1;
            longhornConversionWebhook.replicas = 1;
            longhornAdmissionWebhook.replicas = 1;
            longhornRecoveryBackend.replicas = 1;
            longhornManager = {
              tolerations = [{
                key = "node-role.kubernetes.io/control-plane";
                operator = "Exists";
                effect = "NoSchedule";
              }];
              nodeSelector = {
                "longhorn-storage" = "enabled";
              };
            };
          };
        };
      };
      resources = {
        daemonSets.longhorn-manager = {
          metadata.namespace = ns;
          spec.template.spec.containers.longhorn-manager.env = [{
            name = "PATH";
            value = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/run/current-system/sw/bin";
          }];
        };
        ingressroute.longhorn-dashboard = {
          metadata = {
            name = "longhorn-dashboard";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`longhorn.${flake.lib.hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = "longhorn-frontend";
                    port = 80;
                  }
                ];
              }
            ];
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
        servicemonitors = {
          attrName = "servicemonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "ServiceMonitor";
        };
      };
    };
  };
}
