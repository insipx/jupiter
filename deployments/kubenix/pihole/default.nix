{ kubenix, flake, ... }:
let
  ns = "pihole-sys";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        pihole = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://mojo2600.github.io/pihole-kubernetes";
            chart = "pihole";
            version = "2.35.0";
            sha256 = "sha256-wWFj3/2BsiQMXcAoG8buJRWUXkcKS6Ies1veUtMcHYc=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            serviceDns.type = "LoadBalancer";
            serviceDns.loadBalancerIP = "10.10.68.68";
            serviceDhcp.enabled = false;

            persistentVolumeClaim = {
              enabled = true;
              size = "1Gi";
              storageClass = "longhorn-static";
              accessModes = [ "ReadWriteOnce" ];
            };
            admin = {
              enabled = true;
              existingSecret = "web-admin-creds";
              passwordKey = "admin-pass";
            };
            DNS1 = "10.10.69.1#53";
            DNS2 = "10.10.69.1#53";
            monitoring.podMonitor.enabled = true;
          };
        };
      };
      resources = {
        # Internal IngressRoute - accessible from jupiter.lan network without client cert
        ingressroute.pihole-web = {
          metadata.namespace = ns;
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`pihole.${flake.lib.hostname}`)";
                kind = "Rule";
                services = [
                  {
                    name = "pihole-web"; # check the service name the chart creates
                    port = 80; # default pihole port
                  }
                ];
              }
            ];
            tls = { };
          };
        };
        secrets = {
          web-admin-creds = {
            metadata = {
              name = "web-admin-creds";
              namespace = ns;
            };
            # Use 'data' instead of 'stringData' because the certificate is already base64-encoded
            # 'stringData' would double-encode it, causing "invalid certificate(s) content" error
            stringData = {
              admin-pass = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/pihole_admin";
            };
          };
        };
      };
      customTypes = {
        ingressroute = {
          attrName = "ingressroute";
          group = "traefik.io";
          version = "v1alpha1";
          kind = "IngressRoute";
        };
        servicemonitors = {
          attrName = "podmonitors";
          group = "monitoring.coreos.com";
          version = "v1";
          kind = "PodMonitor";
        };
      };
    };
  };
}
