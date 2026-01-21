{ kubenix, ... }:
let
  ns = "kube-system";
in
{

  imports = with kubenix.modules;
    [ k8s submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.kube-system = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases.traefik = {
        chart = kubenix.lib.helm.fetch {
          repo = "https://helm.traefik.io/traefik";
          chart = "traefik";
          version = "38.0.1";
          sha256 = "sha256-uq7a+/Y1KryUUebMhqQJNe2fQmUH6b+neqo31OvkYcs=";
        };
        includeCRDs = true;
        noHooks = true;
        namespace = ns;
        values = {
          logs.general.level = "DEBUG";

          persistence = {
            enabled = false;
            storageClass = "longhorn-static";
          };
          # enable metal lb
          service.type = "LoadBalancer";
        };
      };
      resources = {
        ingressroute.traefik-dashboard = {
          metadata = {
            name = "traefik-dashboard";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "web" ];
            routes = [
              {
                match = "Host(`traefik.jupiter.lan`)";
                kind = "Rule";
                services = [
                  {
                    name = "api@internal";
                    kind = "TraefikService";
                  }
                ];
              }
            ];
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
      };
    };
  };
}


