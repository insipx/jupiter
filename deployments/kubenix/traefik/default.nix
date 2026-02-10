{ kubenix, flake, ... }:
let
  ns = "kube-system";
in
{
  # Traefik configuration with selective mTLS support
  #
  # Architecture:
  #   - Internal routes (port 443): No mTLS, wildcard cert, accessible from jupiter.lan
  #   - External routes (port 8443): mTLS required, for internet-facing services via Rathole
  #
  # mTLS Flow:
  #   1. Step CA (volos.jupiter.lan) issues both server and client certificates
  #   2. Server certs: Issued via cert-manager/step-issuer (automated)
  #   3. Client certs: Issued manually via `step ca certificate` command
  #   4. Traefik verifies client certs against Step CA root certificate
  #
  # Generating Client Certificates:
  #   step ca certificate user@jupiter.lan user.crt user.key
  #
  # Testing mTLS:
  #   # Without client cert (should fail on external entrypoint):
  #   curl https://10.10.68.1:8443
  #
  #   # With client cert (should succeed):
  #   curl --cert user.crt --key user.key --cacert ca.crt https://10.10.68.1:8443
  #
  # Rathole Configuration:
  #   Configure Rathole on Fly.io to forward to: 10.10.68.1:8443

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
          version = "39.1.0-ea.1";
          sha256 = "sha256-7MVT4menBVU8QQBYgvBZeFcBEY2PGw3D9bGuMn0YgtA=";
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
            # Rathole on Fly.io should forward to 10.10.68.1:8443
            websecure-external = {
              port = 8443;
              protocol = "TCP";
              targetPort = "websecure-external";
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


