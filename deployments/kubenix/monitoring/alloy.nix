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
            args = [
              "run"
              "/etc/alloy/config.alloy"
              "--server.http.listen-addr=0.0.0.0:${toString alloyImg.port}"
              "--storage.path=/data"
            ];
            ports."http" = {
              containerPort = alloyImg.port;
              protocol = "TCP";
            };
            volumeMounts = [
              {
                name = "alloy-config";
                mountPath = "/etc/alloy/config.alloy";
                subPath = "config.alloy";
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
      resources.requests.storage = "10Gi";
    };
  };
  configMaps = {
    alloy-config.data."config.alloy" = ''
      prometheus.remote_write "default" {
        endpoint {
          url = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/write"
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

        forward_to = [prometheus.remote_write.default.receiver]
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
        name = "http";
        inherit (alloyImg) port;
        targetPort = alloyImg.port;
      }];
      type = "ClusterIP";
      # ports."${toString alloyImg.port}".targetPort = exporterImg.port;
    };
  };
  ingressroute.alloy-dashboard = {
    metadata.namespace = ns;
    metadata.name = "alloy-dashboard";
    spec = {
      entryPoints = [ "websecure" ];
      routes = [
        {
          match = "Host(`alloy.${flake.lib.hostname}`)";
          kind = "Rule";
          services = [
            {
              name = "alloy";
              port = 12345;
            }
          ];
        }
      ];
    };
  };
}
