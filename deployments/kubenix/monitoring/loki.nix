{ kubenix, flake, ... }:
let
  ns = "monitoring";
in
{
  helm.releases = {
    loki = {
      chart = kubenix.lib.helm.fetch {
        repo = "https://grafana.github.io/helm-charts";
        chart = "loki";
        version = "6.53.0";
        sha256 = "sha256-zKHqCE6ffaC3+IfHyQXiEHNVHCRtLEqKBHPon/v8ZG4=";
      };
      namespace = ns;
      values = {
        loki = {
          auth_enabled = false;
          # configure STS with IAM Roles: https://grafana.com/docs/loki/latest/configure/storage/#aws-deployment-s3-single-store
          storage = {
            type = "s3";
            s3 = {
              region = "us-east-1";
              insecure = false;
            };
            bucketNames = {
              chunks = "loki-homelab-storage";
              ruler = "loki-homelab-storage";
              admin = "loki-homelab-storage";
            };
          };
          storage_config = {
            tsdb_shipper = {
              active_index_directory = "/var/loki/index";
              cache_location = "/var/loki/index_cache";
              cache_ttl = "48h";
            };
            aws = {
              region = "us-east-1";
              bucketnames = "loki-homelab-storage";
            };
          };
          schemaConfig.configs = [
            {
              from = "2024-04-01";
              store = "tsdb";
              object_store = "s3";
              schema = "v13";
              index = {
                prefix = "loki_index_";
                period = "24h";
              };
            }
          ];
          ingester.chunk_encoding = "snappy";
          pattern_ingester.enabled = true;
          limits_config = {
            allow_structured_metadata = true;
            volume_enabled = true;
          };
          # minio.enabled = true;
          deploymentMode = "SimpleScalable";
          querier.max_concurrent = 8;
        };
        read.extraEnvFrom = [{ secretRef.name = "s3-loki-bucket"; }];
        write.extraEnvFrom = [{ secretRef.name = "s3-loki-bucket"; }];
        backend.extraEnvFrom = [{ secretRef.name = "s3-loki-bucket"; }];
        # Enable env var expansion in Loki config
        read.extraArgs = [ "-config.expand-env=true" ];
        write.extraArgs = [ "-config.expand-env=true" ];
        backend.extraArgs = [ "-config.expand-env=true" ];
        # Longhorn persistence for each component
        write.persistence.volumeClaimsEnabled = true;
        write.persistence.dataStorage = {
          storageClass = "longhorn-static";
          accessModes = [ "ReadWriteOnce" ];
          size = "50Gi";
        };
        read.persistence.volumeClaimsEnabled = true;
        read.persistence.dataStorage = {
          storageClass = "longhorn-static";
          accessModes = [ "ReadWriteOnce" ];
          size = "50Gi";
        };
        backend.persistence.volumeClaimsEnabled = true;
        backend.persistence.dataStorage = {
          storageClass = "longhorn-static";
          accessModes = [ "ReadWriteOnce" ];
          size = "50Gi";
        };

        # Enable Prometheus ServiceMonitor
        serviceMonitor = {
          enabled = true;
        };
      };
    };
  };
  resources = {
    secrets.s3_loki_bucket = {
      metadata.namespace = ns;
      metadata.name = "s3-loki-bucket";
      stringData = {
        AWS_ACCESS_KEY_ID = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/s3_loki_key";
        AWS_SECRET_ACCESS_KEY = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/s3_loki_secret";
      };
    };
  };
}
