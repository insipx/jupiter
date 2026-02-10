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
        version = "80.14.4";
        sha256 = "sha256-edZNrpeFAPOesVC+BFBbAAafFyZc/m5Dy26lJpzakG0=";
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
            providers = [{
              name = "default";
              orgId = 1;
              folder = "";
              type = "file";
              disableDeletion = true;
              editable = true;
              options.path = "/var/lib/grafana/dashboards/default";
            }];
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
          relabelings = [{
            sourceLabels = [ "__meta_kubernetes_pod_node_name" ];
            targetLabel = "instance";
          }];
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
  };
}
