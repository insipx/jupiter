{ flake, ... }:
let
  ns = "monitoring";
  alloyImg = {
    label = "alloy";
    version = "v1.12.2";
    port = 12345;
    imagePolicy = "IfNotPresent";
  };
  lokiPort = 1514;
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
          # Init container to download GeoIP database
          initContainers.geoip-download = {
            name = "geoip-download";
            image = "curlimages/curl:8.11.0";
            command = [ "/bin/sh" "-c" ];
            args = [
              ''
                for i in 1 2 3 4 5; do
                  curl -sSL "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=$MAXMIND_LICENSE_KEY&suffix=tar.gz" \
                    -o /geoip/GeoLite2-City.tar.gz && break
                  echo "Attempt $i failed, retrying..."
                  sleep 10
                done
                cd /geoip && tar xzf GeoLite2-City.tar.gz --strip-components=1
                rm -f GeoLite2-City.tar.gz
                ls -la /geoip/
              ''
            ];
            env = [{
              name = "MAXMIND_LICENSE_KEY";
              valueFrom.secretKeyRef = {
                name = "maxmind-license";
                key = "license-key";
              };
            }];
            volumeMounts = [{
              name = "geoip-data";
              mountPath = "/geoip";
            }];
          };
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
            ports."ingest-udp" = {
              containerPort = lokiPort;
              protocol = "UDP";
            };
            ports."ingest-tcp" = {
              containerPort = lokiPort;
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
              {
                name = "geoip-data";
                mountPath = "/etc/alloy/geoip";
              }
            ];
            resources = {
              requests = {
                memory = "256Mi";
                cpu = "200m";
              };
              limits = {
                memory = "512Mi";
                cpu = "1000m";
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
            {
              name = "geoip-data";
              emptyDir = { };
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
      resources.requests.storage = "35Gi";
    };
  };
  configMaps = {
    # https://grafana.com/docs/loki/latest/get-started/labels/
    alloy-config.data."config.alloy" = builtins.readFile ./config.alloy;
  };
  secrets.maxmind-license = {
    metadata.namespace = ns;
    metadata.name = "maxmind-license";
    stringData = {
      license-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/maxmind_license_key";
    };
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
    };
  };
  services.alloy-loki-ingest = {
    metadata.namespace = ns;
    spec = {
      selector.app = "${alloyImg.label}";
      ports = [{
        name = "ingest-udp";
        port = lokiPort;
        targetPort = lokiPort;
        protocol = "UDP";
      }
        {
          name = "ingest-tcp";
          port = lokiPort;
          targetPort = lokiPort;
          protocol = "TCP";
        }];
      type = "LoadBalancer";
      loadBalancerIP = "10.10.68.100";
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
