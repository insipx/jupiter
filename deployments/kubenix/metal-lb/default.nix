{ kubenix, lib, ... }:
let
  ns = "metallb-system";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.metallb-system = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        metallb = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://metallb.github.io/metallb";
            chart = "metallb";
            # Pinned to 0.16.1: 0.16.x speaker has a ServiceL2Status reconcile
            # loop (metallb/metallb#3063, OPEN/no fix) that POSTs ServiceL2Status
            # objects with resourceVersion set, flooding the apiserver+etcd with
            # "resourceVersion should not be set on objects to be created" at
            # ~20-30/s and burning the kube-apiserver SLO error budget. 0.16.1 is
            # the last release confirmed clean by the issue's bisection.
            version = "0.16.1";
            sha256 = "sha256-KWdVaF6CjFjeHQ6HT1WvkI9JnSurt9emLVCpkxma0fg=";
          };
          namespace = ns;
          values = {
            controller.serviceMonitor = {
              enabled = true;
            };
            speaker.serviceMonitor = {
              enabled = true;
            };
            # chart >=0.16 defaults this to true, pulling in the frr-k8s BGP
            # backend; unneeded for L2 mode, and its webhook Service ports omit
            # `protocol`, which kubenix's ServicePort list-merge requires
            frrk8s.enabled = false;
          };
        };
      };
      resources = {
        services.metallb-webhook-service = {
          spec = {
            ports = lib.mkForce [
              {
                port = 443;
                targetPort = 9443;
                protocol = "TCP";
              }
            ];
          };
        };
        IPAddressPool.default = {
          metadata = {
            namespace = ns;
          };
          spec = {
            addresses = [
              "10.10.68.0/24"
            ];
            autoAssign = true;
            avoidBuggyIPs = true;
          };
        };
        L2Advertisement.default = {
          metadata = {
            namespace = ns;
          };
        };
      };
      customTypes = {
        IPAddressPool = {
          attrName = "IPAddressPool";
          group = "metallb.io";
          version = "v1beta1";
          kind = "IPAddressPool";
        };
        L2Advertisement = {
          attrName = "L2Advertisement";
          group = "metallb.io";
          version = "v1beta1";
          kind = "L2Advertisement";
        };
        servicemonitors = {
          attrName = "servicemonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "ServiceMonitor";
        };
      };
    };
  };
}
