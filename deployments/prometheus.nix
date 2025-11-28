{ kubenix, config, pkgs, ... }:
let
  prometheusApp = {
    label = "prometheus-server";
    port = 9090;
    imagePolicy = "Always";
    # recuires rec (recursive attr)
    # env = [{ name = "APP_PORT"; value = "${toString port}"; }];
  };
  prometheusConfig = ''
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
  '';
in
{
  imports = with kubenix.modules; [ k8s docker ];
  docker = {
    registry.url = "ghcr.io/insipx";
    images.prometheus-monitoring.image = pkgs.callPackage ./../images/prometheus.nix { };
  };
  kubernetes.resources.configMaps.prometheus-config = {
    metadata.name = "prometheus-config";
    data."prometheus.yml" = prometheusConfig;
  };
  kubernetes.resources.deployments."${prometheusApp.label}" = {
    metadata.labels.app = prometheusApp.label;
    spec = {
      replicas = 1;
      selector.matchLabels.app = prometheusApp.label;
      template = {
        metadata.labels.app = prometheusApp.label;
        spec = {
          containers."${prometheusApp.label}" = {
            # inherit (prometheusApp) env;
            name = "${prometheusApp.label}";
            image = config.docker.images.prometheus-monitoring.path;
            imagePullPolicy = prometheusApp.imagePolicy;
            args = [
              "--config.file=/etc/prometheus/prometheus.yml"
              "--storage.tsdb.path=/prometheus"
            ];
            ports."http" = {
              containerPort = 9090;
              protocol = "TCP";
            };
            volumeMounts = [
              {
                name = "config";
                mountPath = "/etc/prometheus";
              }
            ];
            # resources.requests.cpu = prometheusApp.cpu;
            # ports."${toString prometheusApp.port}" = { };
          };
          volumes.config = {
            configMap.name = "prometheus-config";
          };
        };
      };
    };
  };
  kubernetes.resources.services."${prometheusApp.label}" = {
    spec.selector.app = "${prometheusApp.label}";
    spec.ports = [
      {
        name = "prometheus";
        port = 9090;
      }
    ];
    # spec.ports."${toString prometheusApp.port}".targetPort = prometheusApp.port;
  };
}
