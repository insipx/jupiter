{ flake, ... }:
let
  ns = "monitoring";
  exporter = {
    label = "kasa-exporter";
    # Built in-repo (apps/kasa-exporter) and pushed to GHCR by CI.
    image = "ghcr.io/insipx/jupiter/kasa-exporter:latest";
    port = 9101;
    # Kasa devices on the IoT VLAN, targeted by IP (CNI can't UDP-broadcast).
    # python-kasa auto-detects each device's transport (legacy/KLAP/SMART),
    # so one instance with credentials covers all of them.
    targets = [
      "192.168.50.25" # HS300 power strip
      "192.168.50.26" # KP125M (Cyberpower UPS)
    ];
  };
in
{
  resources = {
    secrets.kasa-credentials = {
      metadata.namespace = ns;
      metadata.name = "kasa-credentials";
      stringData = {
        username = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/tplink_username";
        password = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/tplink_password";
      };
    };

    deployments."${exporter.label}" = {
      metadata.labels.app = exporter.label;
      metadata.namespace = ns;
      spec = {
        replicas = 1;
        selector.matchLabels.app = exporter.label;
        template = {
          metadata.labels.app = exporter.label;
          spec.containers."${exporter.label}" = {
            name = exporter.label;
            image = exporter.image;
            imagePullPolicy = "Always";
            args = [
              "--listen=0.0.0.0:${toString exporter.port}"
              "--scrape-interval=15"
            ]
            ++ map (t: "--target=${t}") exporter.targets;
            env = [
              {
                name = "KASA_USERNAME";
                valueFrom.secretKeyRef = {
                  name = "kasa-credentials";
                  key = "username";
                };
              }
              {
                name = "KASA_PASSWORD";
                valueFrom.secretKeyRef = {
                  name = "kasa-credentials";
                  key = "password";
                };
              }
            ];
            ports."metrics" = {
              containerPort = exporter.port;
              protocol = "TCP";
            };
          };
        };
      };
    };

    services."${exporter.label}" = {
      metadata.namespace = ns;
      spec = {
        selector.app = exporter.label;
        ports = [
          {
            name = "metrics";
            port = exporter.port;
            targetPort = exporter.port;
          }
        ];
        type = "ClusterIP";
      };
    };
  };
}
