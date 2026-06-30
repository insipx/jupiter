{ kubenix, flake, ... }:
let
  ns = "monitoring";
in
{
  helm.releases.cloudwatch-exporter = {
    chart = kubenix.lib.helm.fetch {
      repo = "https://prometheus-community.github.io/helm-charts";
      chart = "prometheus-yet-another-cloudwatch-exporter";
      version = "0.46.1";
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
    # NOTE: the Grafana dashboard for the aws_* metrics lives in the jupiter-grafana
    # repo (Git Sync), not as a ConfigMap here — see ../jupiter-grafana/cloudwatch.json.

    # Alerts. These fire into Alertmanager; no receiver is wired yet, so they show
    # in the Alertmanager UI but do not notify externally until a receiver is added.
    # NOTE: the `job` label below assumes the ServiceMonitor names the job
    # "cloudwatch-exporter-prometheus-yet-another-cloudwatch-exporter" (release-chart).
    # Verify after deploy with `up` in Prometheus and adjust the matcher if different.
    prometheusrule.cloudwatch-alerts = {
      metadata.namespace = ns;
      metadata.name = "cloudwatch-alerts";
      metadata.labels."prometheus" = "kube-prometheus-stack-prometheus";
      spec.groups = [
        {
          name = "cloudwatch";
          rules = [
            {
              # The exporter is unreachable -> the AWS dashboard goes silently blank.
              alert = "CloudWatchExporterDown";
              expr = "up{job=~\".*cloudwatch.*\"} == 0";
              "for" = "10m";
              labels.severity = "warning";
              annotations = {
                summary = "YACE CloudWatch exporter is down";
                description = "The cloudwatch exporter has not been scrapeable for 10 minutes; AWS metrics/cost data are stale.";
              };
            }
            {
              # The failure unique to this exporter: its own GetMetricData calls
              # inflating the CloudWatch bill line (was $0.00 before YACE).
              alert = "CloudWatchSelfCostHigh";
              expr = "aws_billing_estimated_charges_maximum{service_name=\"AmazonCloudWatch\"} > 2";
              "for" = "1h";
              labels.severity = "warning";
              annotations = {
                summary = "CloudWatch (YACE) estimated charges above $2";
                description = "AWS CloudWatch estimated charges this month are {{ $value | printf \"%.2f\" }} USD — likely YACE GetMetricData volume. Check scrape interval / namespace scope.";
              };
            }
            {
              # Overall AWS bill past the ~$23 baseline -> a cost surprise somewhere.
              alert = "AWSBillOverBudget";
              expr = "sum(aws_billing_estimated_charges_maximum) > 40";
              "for" = "1h";
              labels.severity = "warning";
              annotations = {
                summary = "Total AWS estimated bill over $40";
                description = "Month-to-date AWS estimated charges are {{ $value | printf \"%.2f\" }} USD, above the ~$23 baseline. Check the CloudWatch dashboard for the service driving it.";
              };
            }
          ];
        }
      ];
    };
  };
}
