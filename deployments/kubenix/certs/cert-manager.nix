{ kubenix, ... }:
let
  ns = "cert-manager";
in
{
  imports = with kubenix.modules; [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.cert-manager = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        cert-manager = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://charts.jetstack.io";
            chart = "cert-manager";
            version = "v1.20.0-alpha.1";
            sha256 = "sha256-SvYpSi9OQnPhSLaxdl/Z30QQyZczsxqDfiqcLl+EW/o=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            global.leaderElection.namespace = ns;
            prometheus.enabled = true;
            prometheus.podmonitor.enabled = true;
          };
        };
      };
      customTypes = {
        certificate = {
          attrName = "certificate";
          group = "cert-manager.io";
          version = "v1";
          kind = "Certificate";
        };
        certificateRequest = {
          attrName = "certificaterequest";
          group = "cert-manager.io";
          version = "v1";
          kind = "CertificateRequest";
        };
        podmonitors = {
          attrName = "podmonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "PodMonitor";
        };
      };
    };
  };
}
