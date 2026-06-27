{ kubenix, flake, ... }:
let
  ns = "monitoring";
in
{
  helm.releases = {
    kube-prometheus-stack = {
      chart = kubenix.lib.helm.fetch {
        repo = "https://prometheus-community.github.io/helm-charts";
        chart = "kube-prometheus-stack";
        version = "86.2.0";
        sha256 = "sha256-P3q256QMrdKkc5H9aQvWWtyoagCDZOObf5wW60ljrRw=";
      };
      namespace = ns;
      # includeCRDs = true; fails
      values = {

        kubeControllerManager.enabled = false;
        kubeScheduler.enabled = false;
        kubeProxy.enabled = false;
        kubeEtcd.enabled = false;
        coreDns.enabled = false; # ns conflict

        prometheus = {
          prometheusSpec = {
            # externalUrl = "https://prometheus.${flake.lib.hostname}";
            serviceMonitorSelectorNilUsesHelmValues = false;
            podMonitorSelectorNilUsesHelmValues = false;
            enableRemoteWriteReceiver = true;
            storageSpec.volumeClaimTemplate.spec = {
              storageClassName = "longhorn-static";
              accessModes = [ "ReadWriteOnce" ];
              resources.requests.storage = "35Gi";
            };
            # Traefik now uses ServiceMonitor instead of static config
            # additionalScrapeConfigs can be used for external targets not in k8s
          };
        };

        alertmanager = {
          # alertmanagerSpec.externalUrl = "https://alertmanager.${flake.lib.hostname}";
          #  ingress = {
          #    enabled = true;
          #    hosts = [ "alertmanager.${flake.lib.hostname}" ];
          #    pathType = "ImplementationSpecific";
          #  };
        };

        grafana = {
          defaultDashboardsEnabled = true;
          defaultDashboardsTimezone = "America/New_York";
          # Persist Grafana's DB on Longhorn. Grafana 13's Unified Storage (which backs
          # Git Sync and UI-saved dashboards) lives in this store; without a PVC it sits
          # on emptyDir and is wiped on every pod restart.
          persistence = {
            enabled = true;
            type = "pvc";
            storageClassName = "longhorn-static";
            accessModes = [ "ReadWriteOnce" ];
            size = "10Gi";
          };
          # grafana-llm-app: self-hosted LLM features (Anthropic provider), provisioned below.
          # grafana-assistant-app: paid/entitlement-gated partner plugin that also needs a
          # Grafana Cloud connection completed interactively in the UI; if its download fails
          # at pod start it can block the Grafana rollout — remove it here if Grafana hangs.
          plugins = [
            "grafana-llm-app"
            "grafana-assistant-app"
          ];
          # Anthropic API key injected from the sops-backed secret as $ANTHROPIC_API_KEY,
          # referenced by the grafana-llm-app provisioning file.
          envValueFrom = {
            ANTHROPIC_API_KEY = {
              secretKeyRef = {
                name = "grafana-llm-credentials";
                key = "anthropic-api-key";
              };
            };
            # InfluxDB 3 Core admin bearer token, exposed to Grafana's process env so the
            # InfluxDB-Kasa datasource below can interpolate it as $INFLUXDB_TOKEN. Reuses
            # the secret created by kasa-collector.nix (same influxdb3_admin_token from sops).
            INFLUXDB_TOKEN = {
              secretKeyRef = {
                name = "kasa-collector-influx";
                key = "token";
              };
            };
          };
          # Mount the grafana-llm-app provisioning file into Grafana's plugin provisioning dir.
          extraConfigmapMounts = [
            {
              name = "grafana-llm-provisioning";
              mountPath = "/etc/grafana/provisioning/plugins/llm.yaml";
              subPath = "llm.yaml";
              configMap = "grafana-llm-provisioning";
              readOnly = true;
            }
          ];
          admin = {
            existingSecret = "grafana-admin-credentials";
            userKey = "admin-user";
            passwordKey = "admin-password";
          };
          "grafana.ini" = {
            "auth.anonymous" = {
              enabled = true;
              org_name = "Main Org.";
              org_role = "Viewer";
            };
            security.allow_embedding = true;
            replicas = 1;
          };
          dashboardProviders."dashboardproviders.yaml" = {
            apiVersion = 1;
            providers = [
              {
                name = "default";
                orgId = 1;
                folder = "";
                type = "file";
                disableDeletion = true;
                editable = true;
                options.path = "/var/lib/grafana/dashboards/default";
              }
            ];
          };
          additionalDataSources = [
            {
              name = "Loki";
              type = "loki";
              url = "http://loki-gateway:80";
              access = "proxy";
              jsonData = {
                httpHeaderName1 = "X-Scope-OrgID";
              };
              secureJsonData = {
                httpHeaderValue1 = "fake";
              };
            }
            # InfluxDB 3 Core (kasa power data). Core has no Flux, so query via InfluxQL.
            # Token handling: this repo's grafana chart values are NOT vals-resolved — every
            # secret reaches grafana via a k8s Secret + existingSecret/envValueFrom (see the
            # admin existingSecret and the ANTHROPIC_API_KEY env above), and `ref+sops://`
            # appears only inside `secrets.*` resources, never in chart values. So we inject
            # the bearer token through Grafana's env ($INFLUXDB_TOKEN, wired via envValueFrom)
            # and interpolate it here; Grafana expands $VAR in provisioned datasource fields.
            {
              name = "InfluxDB-Kasa";
              type = "influxdb";
              url = "http://influxdb3-core:8181";
              access = "proxy";
              jsonData = {
                version = "InfluxQL";
                dbName = "kasa";
                httpHeaderName1 = "Authorization";
              };
              secureJsonData = {
                httpHeaderValue1 = "Bearer $INFLUXDB_TOKEN";
              };
            }
          ];
          dashboards.default = {
            node-exporter-full = {
              gnetId = 1860;
              revision = 31;
              datasource = "Prometheus";
            };
            # YACE / CloudWatch overview (community). Complements the cost-focused
            # cloudwatch.json in the jupiter-grafana (Git Sync) repo.
            yace-cloudwatch = {
              gnetId = 21327;
              revision = 1;
              datasource = "Prometheus";
            };
          };
        };

        prometheus-node-exporter.prometheus.monitor = {
          enabled = true;
          attachMetadata.node = true;
          relabelings = [
            {
              sourceLabels = [ "__meta_kubernetes_pod_node_name" ];
              targetLabel = "instance";
            }
          ];
        };

      };
    };
  };
  resources = {
    ingressroute.grafana-dashboard = {
      metadata.namespace = ns;
      metadata.name = "grafana-dashboard";
      spec = {
        entryPoints = [ "websecure" ];
        routes = [
          {
            match = "Host(`grafana.${flake.lib.hostname}`)";
            kind = "Rule";
            services = [
              {
                name = "kube-prometheus-stack-grafana";
                port = 80;
              }
            ];
          }
        ];
        tls = { };
      };
    };
    ingressroute.prometheus-web = {
      metadata = {
        namespace = ns;
        name = "prometheus-web";
      };
      spec = {
        entryPoints = [ "websecure" ];
        routes = [
          {
            match = "Host(`prometheus.${flake.lib.hostname}`)";
            kind = "Rule";
            services = [
              {
                name = "kube-prometheus-stack-prometheus";
                port = 9090;
              }
            ];
          }

        ];
      };
    };
    secrets.grafana-admin-credentials = {
      metadata.namespace = ns;
      metadata.name = "grafana-admin-credentials";
      stringData = {
        admin-user = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/grafana_admin";
        admin-password = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/grafana_password";
      };
    };
    # Anthropic API key for the grafana-llm-app plugin (mirrors the admin-creds sops pattern).
    # Requires `anthropic_api_key` to exist in homelab.yaml.
    secrets.grafana-llm-credentials = {
      metadata.namespace = ns;
      metadata.name = "grafana-llm-credentials";
      stringData.anthropic-api-key = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/anthropic_api_key";
    };
    configMaps = {
      # Provisioning file that configures grafana-llm-app to use Anthropic.
      # secureJsonData reads $ANTHROPIC_API_KEY from the pod env (set via envValueFrom).
      grafana-llm-provisioning = {
        metadata.namespace = ns;
        data."llm.yaml" = ''
          apiVersion: 1
          apps:
            - type: grafana-llm-app
              disabled: false
              jsonData:
                provider: anthropic
              secureJsonData:
                anthropicKey: $ANTHROPIC_API_KEY
        '';
      };
    };
    prometheusrule.unbound-alerts = {
      metadata.namespace = ns;
      metadata.name = "unbound-alerts";
      metadata.labels."prometheus" = "kube-prometheus-stack-prometheus";
      spec.groups = [
        {
          name = "unbound";
          rules = [
            {
              alert = "UnboundExporterDown";
              expr = "up{job=\"unbound\"} == 0";
              "for" = "5m";
              labels.severity = "critical";
              annotations = {
                summary = "Unbound exporter is down";
                description = "Unbound exporter on {{ $labels.instance }} has been down for more than 5 minutes.";
              };
            }
            {
              alert = "UnboundDown";
              expr = "unbound_up == 0";
              "for" = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Unbound DNS resolver is down";
                description = "Unbound DNS resolver is not responding to the exporter.";
              };
            }
            {
              alert = "UnboundHighRecursionTime";
              expr = "histogram_quantile(0.95, rate(unbound_response_time_seconds_bucket[5m])) > 2";
              "for" = "10m";
              labels.severity = "warning";
              annotations = {
                summary = "Unbound DNS high recursion time";
                description = "95th percentile DNS recursion time is above 2 seconds for 10 minutes.";
              };
            }
            {
              alert = "UnboundCacheHitRateLow";
              expr = "rate(unbound_cache_hits_total[5m]) / (rate(unbound_cache_hits_total[5m]) + rate(unbound_cache_misses_total[5m])) < 0.5";
              "for" = "15m";
              labels.severity = "warning";
              annotations = {
                summary = "Unbound cache hit rate is low";
                description = "Unbound cache hit rate has dropped below 50% for 15 minutes.";
              };
            }
          ];
        }
      ];
    };
  };
}
