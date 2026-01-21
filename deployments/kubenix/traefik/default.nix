{ kubenix, flake, ... }:
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
          ports = {
            web = {
              port = 80;
              protocol = "TCP";
              targetPort = "web";
            };
            websecure = {
              port = 443;
              protocol = "TCP";
              targetPort = "websecure";
            };
          };
        };
      };
      resources = {
        # services.traefik = {
        #   # spec = { };
        # };
        middleware.traefik-https-redirect = {
          metadata = {
            name = "traefik-https-redirect";
            namespace = ns;
          };
          spec = {
            redirectScheme = {
              scheme = "https";
              permanent = true;
            };
          };
        };
        ingressroute.https-redirect = {
          metadata = {
            name = "https-redirect";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "web" ];
            routes = [
              {
                match = "HostRegexp(`.+`)";
                kind = "Rule";
                priority = 1;
                middlewares = [
                  {
                    name = "traefik-https-redirect";
                    namespace = ns;
                  }
                ];
                # dummy service
                services = [
                  {
                    name = "noop@internal";
                    kind = "TraefikService";
                  }
                ];
              }
            ];
          };
        };
        ingressroute.traefik-dashboard = {
          metadata = {
            name = "traefik-dashboard";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "websecure" ];
            routes = [
              {
                match = "Host(`traefik.${flake.lib.hostname}`)";

                kind = "Rule";
                services = [
                  {
                    name = "api@internal";
                    kind = "TraefikService";
                  }
                ];
              }
            ];
            tls = {
              secretName = "traefik-wildcard-tls-secret";
            };
          };
        };
        certificate.traefik-tls = {
          metadata = {
            name = "traefik-tls";
            namespace = ns;
          };
          spec = {
            secretName = "traefik-wildcard-tls-secret";
            commonName = "traefik.${flake.lib.hostname}";
            dnsNames = [
              "traefik.${flake.lib.hostname}"
              "*.${flake.lib.hostname}"
            ];
            ipAddresses = [
              "10.10.68.1"
            ];
            duration = "24h";
            renewBefore = "8h";
            issuerRef = {
              group = "certmanager.step.sm";
              kind = "StepClusterIssuer";
              name = "step-issuer";
            };
          };
        };
        # Default TLS store - provides wildcard cert for all IngressRoutes
        tlsstore.default = {
          metadata = {
            name = "default";
            namespace = ns;
          };
          spec = {
            defaultCertificate = {
              secretName = "traefik-wildcard-tls-secret";
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
        certificate = {
          attrName = "certificate";
          group = "cert-manager.io";
          version = "v1";
          kind = "Certificate";
        };
        middleware = {
          attrName = "middleware";
          group = "traefik.io";
          version = "v1alpha1";
          kind = "Middleware";
        };
        tlsstore = {
          attrName = "tlsstore";
          group = "traefik.io";
          version = "v1alpha1";
          kind = "TLSStore";
        };
      };
    };
  };
}


