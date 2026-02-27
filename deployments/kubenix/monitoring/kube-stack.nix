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
        version = "82.4.3";
        sha256 = "sha256-myNBv1Iia1c+YriK5hJWS4CU+2NBK/nSnPHPO2mVcf0=";
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
          ];
          dashboards.default = {
            node-exporter-full = {
              gnetId = 1860;
              revision = 31;
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
    configMaps = {
      grafana-dashboard-opnsense-firewall = {
        metadata.namespace = ns;
        metadata.labels."grafana_dashboard" = "1";
        data."opnsense-firewall.json" = builtins.readFile ./dashboards/opnsense-firewall.json;
      };
      grafana-dashboard-opnsense-geomap = {
        metadata.namespace = ns;
        metadata.labels."grafana_dashboard" = "1";
        data."opnsense-geomap.json" = builtins.readFile ./dashboards/opnsense-geomap.json;
      };
      grafana-dashboard-suricata = {
        metadata.namespace = ns;
        metadata.labels."grafana_dashboard" = "1";
        data."suricata.json" = builtins.readFile ./dashboards/suricata.json;
      };
      grafana-dashboard-unbound-dns = {
        metadata.namespace = ns;
        metadata.labels."grafana_dashboard" = "1";
        data."unbound-dns.json" = builtins.readFile ./dashboards/unbound-dns.json;
      };
      grafana-dashboard-network-traffic = {
        metadata.namespace = ns;
        metadata.labels."grafana_dashboard" = "1";
        data."network-traffic.json" = builtins.readFile ./dashboards/network-traffic.json;
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
