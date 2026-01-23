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
            # External entrypoint with mTLS for internet-facing services (via Rathole)
            # Rathole on Fly.io should forward to 10.10.68.1:8443
            websecure-external = {
              port = 8443;
              protocol = "TCP";
              targetPort = "websecure-external";
            };
          };
        };
      };
      resources = {
        # Step CA root certificate for mTLS client authentication
        # This is the same CA that issues server certificates via cert-manager
        # Used by TLSOption to verify client certificates on websecure-external entrypoint
        secrets.step-ca-root-cert = {
          metadata = {
            name = "step-ca-root-cert";
            namespace = ns;
          };
          type = "Opaque";
          data = {
            # Base64-encoded Step CA root certificate (same as step-issuer caBundle)
            "ca.crt" = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJsRENDQVRtZ0F3SUJBZ0lRWmFuMkwxSmlZaEhUcC95VWdWdUFvekFLQmdncWhrak9QUVFEQWpBb01RNHcKREFZRFZRUUtFd1ZXYjJ4dmN6RVdNQlFHQTFVRUF4TU5WbTlzYjNNZ1VtOXZkQ0JEUVRBZUZ3MHlOREV5TVRreQpNVE15TURGYUZ3MHpOREV5TVRjeU1UTXlNREZhTUNneERqQU1CZ05WQkFvVEJWWnZiRzl6TVJZd0ZBWURWUVFECkV3MVdiMnh2Y3lCU2IyOTBJRU5CTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFalBaQkszMTkKT0ZsNTZXWkcrZnVFWE5BVzZFQ0F6L1VmWG5WaUFua2ZpTmFnL043MitsR3FjMFVNajVURlpqNFRDek9ORTZsUQptUnhla3dmcTJPWVZrcU5GTUVNd0RnWURWUjBQQVFIL0JBUURBZ0VHTUJJR0ExVWRFd0VCL3dRSU1BWUJBZjhDCkFRRXdIUVlEVlIwT0JCWUVGSmZWRnJJem5RaTNXT1JuSFR4RWsxVEMzRWRNTUFvR0NDcUdTTTQ5QkFNQ0Ewa0EKTUVZQ0lRQzM2Mmtxdy82RnVaSHkzSW1XT3RTa0wrYWRoOC9sUktNdHlWOCtNaFNpNEFJaEFPaVlJalR0NXVsdwovN2dWWlBtRXBJRkdPdWJRZ0RPQTY3TTdFODRzazg0NAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==";
          };
        };
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
        # TLSOption for mutual TLS (mTLS) on external routes
        # Requires and verifies client certificates signed by Step CA
        # Apply to IngressRoutes using: tls.options.name = "mtls-required"
        tlsoption.mtls-required = {
          metadata = {
            name = "mtls-required";
            namespace = ns;
          };
          spec = {
            minVersion = "VersionTLS12";
            clientAuth = {
              # Reference to Step CA root certificate secret
              secretNames = [ "step-ca-root-cert" ];
              # Require client certificate and verify it against Step CA
              clientAuthType = "RequireAndVerifyClientCert";
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
      };
    };
  };
}


