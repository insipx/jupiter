{ kubenix, ... }:
let
  ns = "monitoring";
in
{
  imports = with kubenix.modules;
    [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.monitoring = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        kube-prometheus-stack = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://prometheus-community.github.io/helm-charts";
            chart = "kube-prometheus-stack";
            version = "80.9.1";
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
                storageSpec.volumeClaimTemplate.spec = {
                  storageClassName = "longhorn-static";
                  accessModes = [ "ReadWriteOnce" ];
                  resources.requests.storage = "35Gi";
                };
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
              dashboards.default = {
                node-exporter-full = {
                  gnetId = 1860;
                  revision = 31;
                  datasource = "Prometheus";
                };
              };
            };

            prometheus-node-exporter.prometheus.monitor.relabelings = [{
              sourceLabels = [ "__meta_kubernetes_pod_node_name" ];
              targetLabel = "instance";
            }];

          };
        };
      };

      customTypes = {
        servicemonitors = {
          attrName = "servicemonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "ServiceMonitor";
        };
        podmonitors = {
          attrName = "podmonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "PodMonitor";
        };
        alertmanagers = {
          attrName = "alertmanagers";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "Alertmanager";
        };
        prometheus = {
          attrName = "prometheus";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "Prometheus";
        };
        prometheusrule = {
          attrName = "prometheusrule";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "PrometheusRule";
        };
      };
    };
  };
}
