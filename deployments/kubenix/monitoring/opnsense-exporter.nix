{ flake, ... }:
let
  ns = "monitoring";
  exporter = {
    label = "opnsense-exporter";
    version = "0.0.11";
    port = 8080;
    imagePolicy = "IfNotPresent";
    # recuires rec (recursive attr)
  };
in
{
  # docker.images.opnsense-exporter = {
  #   registry = "ghcr.io/athennamind";
  #   name = "opnsense-exporter";
  #   tag = "0.0.11";
  #   # images.prometheus-monitoring.image = pkgs.callPackage ./../images/prometheus.nix { };
  # };

  # Merge resources into the existing monitoring submodule instance
  submodules.instances.${ns}.args.kubernetes.resources = {
    secrets.opnsense-api-credentials = {
      metadata.namespace = ns;
      metadata.name = "opnsense-api-credentials";
      stringData = {
        opnsense-api-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_api_key";
        opnsense-api-secret = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/opnsense_secret_key";

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
          spec = {
            containers."${exporter.label}" = {
              name = "${exporter.label}";
              image = "ghcr.io/athennamind/${exporter.label}:${exporter.version}";
              imagePullPolicy = exporter.imagePolicy;
              args = [
                "--opnsense.protocol=https"
                "--opnsense.address=opnsense.${flake.lib.hostname}"
                "--exporter.instance-label=opnsense-exporter"
                "--opnsense.insecure"
                "--web.listen-address=:8080"
              ];
              env = [
                {
                  name = "OPNSENSE_EXPORTER_OPS_API_KEY";
                  valueFrom = {
                    secretKeyRef = {
                      name = "opnsense-api-credentials";
                      key = "opnsense-api-key";
                    };
                  };
                }
                {
                  name = "OPNSENSE_EXPORTER_OPS_API_SECRET";
                  valueFrom = {
                    secretKeyRef = {
                      name = "opnsense-api-credentials";
                      key = "opnsense-api-secret";
                    };
                  };
                }
              ];
              ports."http" = {
                containerPort = 8080;
                protocol = "TCP";
              };
              # resources.requests.cpu = exporter.cpu;
              # ports."${toString exporter.port}" = { };
            };
          };
        };
      };
    };
    services."${exporter.label}" = {
      metadata.namespace = ns;
      metadata.annotations = {
        "metallb.universe.tf/loadBalancerIPs" = "10.10.68.2";
      };
      spec = {
        selector.app = "${exporter.label}";
        ports = [
          {
            name = "opnsense-exporter";
            port = 8080;
          }
        ];
        type = "LoadBalancer";
        # ports."${toString exporter.port}".targetPort = exporter.port;
      };
    };
  };
}
