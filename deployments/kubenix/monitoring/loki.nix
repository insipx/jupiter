{ kubenix, flake, ... }:
let
  ns = "monitoring";
in
{
  submodules.instances.monitoring.args.kubernetes = {
    helm.releases = {
      loki = {
        chart = kubenix.lib.helm.fetch {
          repo = "https://grafana.github.io/helm-charts";
          chart = "grafana";
          version = "6.51.0";
          sha256 = "sha256-0000000000000000000000000000000000000000000=";
        };
        namespace = ns;
        values = {
          minio.enabled = true;
          deploymentMode = "SimpleScalable";
          querier.max_concurrent = 4;
          ui.enabled = true;
        };
      };
    };
    resources = {
      ingressroute.loki-gateway = {
        metadata.namespace = ns;
        metadata.name = "loki-gateway";
        spec = {
          entrypoints = [ "websecure" ];
          routes = [
            {
              match = "Host(`loki.${flake.lib.hostname}`)";
              kind = "Rule";
              services = [
                {
                  name = "loki-gateway";
                  port = 80;
                }
              ];
            }
          ];
        };
      };
    };
  };
}
