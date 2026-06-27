{
  kubenix,
  lib,
  flake,
  ...
}:
let
  ns = "monitoring";

  alloy = import ./alloy.nix { inherit flake; };
  alloy-logs = import ./alloy-logs.nix { inherit flake; };
  opnsense-exporter = import ./opnsense-exporter.nix { inherit flake; };
  ks-res = (import ./kube-stack.nix { inherit kubenix flake; }).resources;
  ks-helm = (import ./kube-stack.nix { inherit kubenix flake; }).helm.releases;

  loki-helm = (import ./loki.nix { inherit kubenix flake; }).helm.releases;
  loki-res = (import ./loki.nix { inherit kubenix flake; }).resources;

  cloudwatch-helm = (import ./cloudwatch-exporter.nix { inherit kubenix flake; }).helm.releases;
  cloudwatch-res = (import ./cloudwatch-exporter.nix { inherit kubenix flake; }).resources;

  kasa-prometheus = (import ./kasa-prometheus.nix { inherit flake; }).resources;
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
    args.kubernetes.resources = lib.foldl' lib.recursiveUpdate { } [
      ks-res
      alloy
      alloy-logs
      opnsense-exporter
      loki-res
      cloudwatch-res
      kasa-prometheus
    ];
    args.kubernetes.helm.releases = lib.foldl' lib.recursiveUpdate { } [
      ks-helm
      loki-helm
      cloudwatch-helm
    ];
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
