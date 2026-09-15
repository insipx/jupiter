{ kubenix, flake, ... }:
let
  ns = "kube-system";
in
{
  # Traefik with mTLS support
  #
  # Architecture:
  #   - Internal routes (port 443): No mTLS accessible from lan
  #   - External routes (port 8443): mTLS required, this is for external services via rathole proxy
  #
  # mTLS:
  #   1. Step CA (volos.jupiter.lan) issues both server and client certs
  #   2. Server certs are issued with cert-manager
  #   3. Client certs are issued manually via `step ca certificate` command
  #
  # Generating Client Certificates:
  #   step ca certificate user@jupiter.lan user.crt user.key
  #
  # Testing:
  #   # fails:
  #   curl https://10.10.68.1:8443
  #
  #   # succeeds:
  #   curl --cert user.crt --key user.key --cacert ca.crt https://10.10.68.1:8443
  imports = with kubenix.modules; [
    k8s
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.kube-system = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases.traefik = {
        chart = kubenix.lib.helm.fetch {
          repo = "https://helm.traefik.io/traefik";
          chart = "traefik";
          version = "40.3.0";
          sha256 = "sha256-V8l23cMxhtIg1bPtRLXJvvzlzzcIl/uGWFYATzCKtPI=";
        };
        includeCRDs = true;
        noHooks = true;
        namespace = ns;
        values = {
          logs.general.level = "DEBUG";

          metrics.prometheus = {
            entrypoint = "metrics";
            addRoutersLabels = true;
            addServicesLabels = true;
            serviceMonitor = {
              enabled = true;
            };
          };
          persistence = {
            enabled = false;
            storageClass = "longhorn-static";
          };
          # enable metal lb
          service.type = "LoadBalancer";
          ports = {
            # web and websecure are defaults in traefik
            # Rathole should forward to 10.10.68.1:8443
            websecure-external = {
              port = 8444;
              # LoadBalancer-facing port, the one Rathole targets
              exposedPort = 8443;
              expose.default = true;
              protocol = "TCP";
            };
            # Public site via Rathole -- no mTLS
            # Rathole forwards to 10.10.70.1:8445 (and 10.10.70.1:80 -> web for
            # the https redirect + ACME HTTP-01); see services.traefik-public.
            websecure-public = {
              port = 8446;
              exposedPort = 8445;
              expose.default = false;
              protocol = "TCP";
            };
            # Plain-HTTP twin of websecure-public: https redirect + ACME HTTP-01
            # for public hosts only. Never attach content routes here.
            web-public = {
              port = 8001;
              exposedPort = 80;
              expose.default = false;
              protocol = "TCP";
            };
            metrics = {
              port = 9100;
              protocol = "TCP";
              targetPort = "metrics";
            };
          };
        };
      };
      resources = {
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
            entryPoints = [ "web" "web-public" ];
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
        services.traefik-public = {
          metadata = {
            name = "traefik-public";
            namespace = "kube-system";
            annotations = {
              "metallb.io/address-pool" = "public";
              "metallb.io/loadBalancerIPs" = "10.10.70.1";
            };
          };
          spec = {
            type = "LoadBalancer";
            selector = {
              "app.kubernetes.io/name" = "traefik";
              "app.kubernetes.io/instance" = "traefik-kube-system";
            };
            ports = [
              {
                name = "websecure-public";
                port = 8445;
                targetPort = 8446;
                protocol = "TCP";
              }
              {
                # Plain HTTP for the https redirect and ACME HTTP-01 challenges.
                name = "web-public";
                port = 80;
                targetPort = 8001;
                protocol = "TCP";
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
        tlsoption = {
          attrName = "tlsoption";
          group = "traefik.io";
          version = "v1alpha1";
          kind = "TLSOption";
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
