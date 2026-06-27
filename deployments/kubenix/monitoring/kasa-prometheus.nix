{ ... }:
let
  ns = "monitoring";
  exporter = {
    label = "kasa-prometheus";
    # Built in-repo (pkgs/kasa-prometheus.nix) and pushed to GHCR by CI.
    image = "ghcr.io/insipx/jupiter/kasa-prometheus:latest";
    port = 9101;
    hs300 = "192.168.50.25";
  };
in
{
  resources = {
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
            # HS300 uses the legacy local protocol — no cloud creds. Target the
            # device by IP (CNI overlay can't UDP-broadcast to the LAN), and
            # bind the metrics endpoint on the pod.
            args = [
              "--listen=0.0.0.0:${toString exporter.port}"
              "--target=${exporter.hs300}"
              "--scrape-interval=15"
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
