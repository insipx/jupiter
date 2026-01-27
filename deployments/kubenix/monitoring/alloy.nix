{ flake, ... }:
let
  ns = "monitoring";
  alloyImg = {
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
    # secrets.opnsense-api-credentials = {
    #   metadata.namespace = ns;
    #   metadata.name = "opnsense-api-credentials";
    #   stringData = {
    #     opnsense-api-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_api_key";
    #     opnsense-api-secret = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_secret_key";

    #   };
    # };
    statefulSets."${alloyImg.label}" = {
      metadata.labels.app = alloyImg.label;
      metadata.namespace = ns;
      spec = {
        replicas = 1;
        selector.matchLabels.app = alloyImg.label;
        template = {
          metadata.labels.app = alloyImg.label;
          spec = {
            containers."${alloyImg.label}" = {
              name = "${alloyImg.label}";
              image = "docker.io/grafana/${alloyImg.label}:${alloyImg.version}";
              imagePullPolicy = alloyImg.imagePolicy;
              ports."http" = {
                containerPort = alloyImg.port;
                protocol = "TCP";
              };
              volumeMounts = [
                {
                  name = "alloy-config";
                  mountPath = "/etc/alloy/config.alloy";
                }
                {
                  name = "alloy-data-pvc";
                  mountPath = "/data";
                }
              ];
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
            };
            volumes = [
              {
                name = "alloy-config";
                configMap.name = "alloy-config";
              }
              {
                name = "alloy-data-pvc";
                persistentVolumeClaim.claimName = "alloy-data-pvc";
              }
            ];
          };
        };
      };
    };
    persistentVolumeClaims.alloy-data-pvc = {
      metadata = {
        name = "alloy-data-pvc";
        namespace = ns;
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "longhorn-static";
        resources.requests.storage = "128Gi";
      };
    };
    configMaps = {
      alloy-config.data."config.alloy" = ''
        prometheus.remote_write "default" {
          endpoint {
            url = "http://prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/write"
          }
        }

        prometheus.scrape "opnsense_node" {
          targets = [{
            __address__ = "10.10.69.1:9100",
            instance    = "fw-opnsense",
            job         = "node_exporter",
            group       = "firewall",
            host        = "opnsense.jupiter.lan",
          }]

          forward_to [prometheus.remote_write.default.receiver_id]
          scrape_interval = "15s"
          scrape_timeout = "10s"
        }
      '';
    };
    services."${alloyImg.label}" = {
      metadata.namespace = ns;
      spec = {
        selector.app = "${alloyImg.label}";
        ports = [{
          name = "alloy";
          inherit (alloyImg) port;
        }];
        type = "ClusterIP";
        # ports."${toString alloyImg.port}".targetPort = exporterImg.port;
      };
    };
  };
}
