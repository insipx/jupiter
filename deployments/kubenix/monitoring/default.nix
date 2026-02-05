{ kubenix, lib, flake, ... }:
let
  ns = "monitoring";

  alloy = import ./alloy.nix { inherit flake; };
  opnsense-exporter = import ./opnsense-exporter.nix { inherit flake; };
  ks-res = (import ./kube-stack.nix { inherit kubenix flake; }).resources;
  ks-helm = (import ./kube-stack.nix { inherit kubenix flake; }).helm.releases;

  loki-helm = (import ./loki.nix { inherit kubenix flake; }).helm.releases;
  loki-res = (import ./loki.nix { inherit kubenix flake; }).resources;

  # Dashboard ConfigMaps (picked up by Grafana sidecar via grafana_dashboard label)
  dashboards = {
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
    };
  };
in
{
  imports = with kubenix.modules; [
    k8s
    docker
    submodules
    helm
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes.resources = lib.foldl' lib.recursiveUpdate { } [ ks-res alloy opnsense-exporter loki-res dashboards ];
    args.kubernetes.helm.releases = lib.recursiveUpdate ks-helm loki-helm;
    args.kubernetes.customTypes = {
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
      ingressroute = {
        attrName = "ingressroute";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRoute";
      };
    };
  };
}

