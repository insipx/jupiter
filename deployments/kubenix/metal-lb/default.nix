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
            version = "0.15.3";
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
