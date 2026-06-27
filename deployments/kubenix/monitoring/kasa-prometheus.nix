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
            # NO credentials. This HS300 (hw2.0, KLAP login-v2, new_klap=1) uses
            # a KLAP v2 challenge that no open library can authenticate yet
            # (python-kasa #1603/#1604). With "Third Party Compatibility" ON in
            # the Kasa app the device reopens the unauthenticated legacy XOR
            # protocol on :9999 — kasa-rs uses that only when no creds are set.
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
