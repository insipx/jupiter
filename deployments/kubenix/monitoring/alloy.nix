{ flake, ... }:
let
  ns = "monitoring";
  exporterImg = {
    label = "alloy";
    version = "v1.12.2";
    port = 12345;
    imagePolicy = "IfNotPresent";
    # recuires rec (recursive attr)
  };
in
{
  # Merge resources into the existing monitoring submodule instance
  submodules.instances.${ns}.args.kubernetes.resources = {
    secrets.opnsense-api-credentials = {
      metadata.namespace = ns;
      metadata.name = "opnsense-api-credentials";
      stringData = {
        opnsense-api-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_api_key";
        opnsense-api-secret = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_secret_key";

      };
    };
    statefulSets."${exporterImg.label}" = {
      metadata.labels.app = exporterImg.label;
      metadata.namespace = ns;
      spec = {
        replicas = 1;
        selector.matchLabels.app = exporterImg.label;
        template = {
          metadata.labels.app = exporterImg.label;
          spec = {
            containers."${exporterImg.label}" = {
              name = "${exporterImg.label}";
              image = "ghcr.io/athennamind/${exporterImg.label}:${exporterImg.label}";
              imagePullPolicy = exporterImg.imagePolicy;
              args = [ ];
              env = [ ];
              ports."http" = {
                containerPort = 8080;
                protocol = "TCP";
              };
              volumeMounts = [{
                name = "alloy-data-pvc";
                mountPath = "/data";
              }];
              resources = {
                requests = {
                  memory = "128Mi";
                  cpu = "100m";
                };
                limits = {
                  memory = "256Mi";
                  cpu = "500m";
                };
              };
              # resources.requests.cpu = exporterImg.cpu;
              # ports."${toString exporterImg.port}" = { };
            };
            volumes = {
              config.configMap.name = "alloy-config";
              persistentVolumeClaim.claimName = "alloy-data-pvc";
            };
          };
        };
      };
    };
    persistentVolumeClaims.alloy-data-pvc.spec = {
      accessModes = [ "ReadWriteMany" ];
      storageClassName = "longhorn-static";
      resources.requests.storage = "128Gi";
    };
    configMaps = {
      alloy-config.data."config.alloy" = ''
      '';
    };
    services."${exporterImg.label}" = {
      metadata.namespace = ns;
      spec = {
        selector.app = "${exporterImg.label}";
        ports = [ ];
        type = "ClusterIP";
        # ports."${toString exporterImg.port}".targetPort = exporterImg.port;
      };
    };
  };
}
