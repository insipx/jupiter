{ kubenix, flake, ... }:
let
  ns = "monitoring";
in
{
  helm.releases.cloudwatch-exporter = {
    chart = kubenix.lib.helm.fetch {
      repo = "https://prometheus-community.github.io/helm-charts";
      chart = "prometheus-yet-another-cloudwatch-exporter";
      version = "0.45.0";
      sha256 = "sha256-U99V8wqVLCn3jnMGKQltFj8iie5lWapnz4IeeHo/eH8=";
    };
    namespace = ns;
    values = {
      # AWS creds from the pre-created secret; YACE expects fields access_key/secret_key.
      aws.secret = {
        name = "yace-aws-credentials";
        includesSessionToken = false;
      };
      # 5-minute scrape interval — CloudWatch GetMetricData is billed per metric.
      extraArgs.scraping-interval = "300";
      # Let Prometheus auto-scrape via ServiceMonitor.
      serviceMonitor = {
        enabled = true;
        namespace = ns;
      };
      # YACE discovery config (config in its own file).
      config = builtins.readFile ./cloudwatch-config.yaml;
    };
  };

  resources = {
    # Dedicated read-only IAM user key via sops. Field names access_key/secret_key
    # are what YACE's aws.secret expects (NOT AWS_ACCESS_KEY_ID).
    secrets.yace-aws-credentials = {
      metadata.namespace = ns;
      metadata.name = "yace-aws-credentials";
      stringData = {
        access_key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/aws_cloudwatch_key";
        secret_key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/aws_cloudwatch_secret";
      };
    };
  };
}
