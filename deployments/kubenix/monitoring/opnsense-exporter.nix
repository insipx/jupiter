{ kubenix, config, flake, ... }:
let
  ns = "monitoring";
  opnsenseExporter = {
    label = "opnsense-exporter";
    port = 8080;
    imagePolicy = "IfNotPresent";
    # recuires rec (recursive attr)
    env = [
      { name = "OS_API_KEY_FILE"; value = config.sops.secrets.opnsense_api_key.path; }
      { name = "OS_API_SECRET_FILE"; value = config.sops.secrets.opnsense_secret_key.path; }
    ];
    secrets = [
      "opnsense-api-key"
      "opnsense-api-secret"
    ];
  };
in
{
  imports = with kubenix.modules; [ k8s docker submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  docker.images.opnsense-exporter = {
    registry = "ghcr.io/athennamind";
    name = "opnsense-exporter";
    tag = "0.0.11";
    # images.prometheus-monitoring.image = pkgs.callPackage ./../images/prometheus.nix { };
  };

  # Merge resources into the existing monitoring submodule instance
  submodules.instances.monitoring.args.kubernetes.resources = {
    deployments."${opnsenseExporter.label}" = {
      metadata.labels.app = opnsenseExporter.label;
      metadata.namespace = ns;
      spec = {
        replicas = 1;
        selector.matchLabels.app = opnsenseExporter.label;
        template = {
          metadata.labels.app = opnsenseExporter.label;
          spec = {
            containers."${opnsenseExporter.label}" = {
              inherit (opnsenseExporter) env secrets;
              name = "${opnsenseExporter.label}";
              image = config.docker.images.opnsense-exporter.path;
              imagePullPolicy = opnsenseExporter.imagePolicy;
              args = [
                "--opnsense.protocol=https"
                "--opnsense.address=opnsense.${flake.lib.hostname}"
                "--exporter.instance-label=instance1"
                "--web.listen-address=:8080"
              ];
              ports."http" = {
                containerPort = 8080;
                protocol = "TCP";
              };
              # resources.requests.cpu = opnsenseExporter.cpu;
              # ports."${toString opnsenseExporter.port}" = { };
            };
          };
        };
      };
    };
    services."${opnsenseExporter.label}" = {
      metadata.namespace = ns;
      spec = {
        selector.app = "${opnsenseExporter.label}";
        ports = [
          {
            name = "opnsense-exporter";
            port = 8080;
          }
        ];
        # ports."${toString opnsenseExporter.port}".targetPort = opnsenseExporter.port;
      };
    };
  };
}
