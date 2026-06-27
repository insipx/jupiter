{ flake, ... }:
let
  ns = "monitoring";
  collector = {
    label = "kasa-collector";
    image = "lux4rd0/kasa-collector:2025.7.0"; # pinned, not :latest
    hs300 = "192.168.50.25";
  };
in
{
  resources = {
    secrets.kasa-collector-influx = {
      metadata.namespace = ns;
      metadata.name = "kasa-collector-influx";
      stringData.token =
        "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/influxdb3_admin_token";
    };

    deployments."${collector.label}" = {
      metadata.labels.app = collector.label;
      metadata.namespace = ns;
      spec = {
        replicas = 1;
        selector.matchLabels.app = collector.label;
        template = {
          metadata.labels.app = collector.label;
          spec.containers."${collector.label}" = {
            name = collector.label;
            image = collector.image;
            imagePullPolicy = "IfNotPresent";
            env = [
              { name = "KASA_COLLECTOR_DEVICE_HOSTS"; value = collector.hs300; }
              { name = "KASA_COLLECTOR_ENABLE_AUTO_DISCOVERY"; value = "false"; }
              { name = "KASA_COLLECTOR_DATA_FETCH_INTERVAL"; value = "15"; }
              { name = "KASA_COLLECTOR_INFLUXDB_URL"; value = "http://influxdb3-core:8181"; }
              { name = "KASA_COLLECTOR_INFLUXDB_ORG"; value = "homelab"; }
              { name = "KASA_COLLECTOR_INFLUXDB_BUCKET"; value = "kasa"; }
              {
                name = "KASA_COLLECTOR_INFLUXDB_TOKEN";
                valueFrom.secretKeyRef = {
                  name = "kasa-collector-influx";
                  key = "token";
                };
              }
            ];
          };
        };
      };
    };
  };
}
