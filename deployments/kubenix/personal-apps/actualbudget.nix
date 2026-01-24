{ kubenix, flake, ... }:
let
  ns = "personal-apps";
in
{
  imports = with kubenix.modules;
    [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        actualbudget = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://community-charts.github.io/helm-charts";
            chart = "actualbudget";
            version = "v1.8.6";
            sha256 = "sha256-D/bQVuVN26EOvZNSwMwOGksqLsVMEspPvdTDkX8bJnU=";
          };
          includeCRDs = true;
          namespace = ns;
          values = {
            persistence = {
              enabled = true;
              size = "25Gi";
              storageClass = "longhorn-static";
              accessModes = [ "ReadWriteOnce" ];
            };
          };
        };
      };
      resources = {
        # Internal IngressRoute - accessible from jupiter.lan network without client cert
        ingressroute.actualbudget = {
          metadata.namespace = ns;
          spec = {
            entryPoints = [ "websecure" ];
            routes = [{
              match = "Host(`budget.${flake.lib.hostname}`)";
              kind = "Rule";
              services = [{
                name = "actualbudget"; # check the service name the chart creates
                port = 5006; # default actualbudget port
              }];
            }];
            tls = { };
          };
        };
        # External IngressRoute - accessible via Rathole with mTLS (client cert required)
        # Rathole on Fly.io should forward to 10.10.68.1:8443
        # Client certificates can be generated using: step ca certificate user@jupiter.lan user.crt user.key
        ingressroute.actualbudget-external = {
          metadata = {
            name = "actualbudget-external";
            namespace = ns;
          };
          spec = {
            entryPoints = [ "websecure-external" ];
            routes = [{
              match = "Host(`budget.${flake.lib.hostname}`)";
              kind = "Rule";
              services = [{
                name = "actualbudget";
                port = 5006;
              }];
            }];
            tls.options.name = "mtls-required";
          };
        };
        tlsoption.mtls-required = {
          metadata = {
            name = "mtls-required";
            namespace = ns;
          };
          spec = {
            minVersion = "VersionTLS12";
            clientAuth = {
              secretNames = [ "volos-cert" ];
              clientAuthType = "RequireAndVerifyClientCert";
            };
          };
        };
        secrets.volos-cert = {
          metadata = {
            name = "volos-cert";
            namespace = ns;
          };
          # Use 'data' instead of 'stringData' because the certificate is already base64-encoded
          # 'stringData' would double-encode it, causing "invalid certificate(s) content" error
          data = {
            # Base64-encoded Step CA root certificate (same as step-issuer caBundle)
            "ca.crt" = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJsRENDQVRtZ0F3SUJBZ0lRWmFuMkwxSmlZaEhUcC95VWdWdUFvekFLQmdncWhrak9QUVFEQWpBb01RNHcKREFZRFZRUUtFd1ZXYjJ4dmN6RVdNQlFHQTFVRUF4TU5WbTlzYjNNZ1VtOXZkQ0JEUVRBZUZ3MHlOREV5TVRreQpNVE15TURGYUZ3MHpOREV5TVRjeU1UTXlNREZhTUNneERqQU1CZ05WQkFvVEJWWnZiRzl6TVJZd0ZBWURWUVFECkV3MVdiMnh2Y3lCU2IyOTBJRU5CTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFalBaQkszMTkKT0ZsNTZXWkcrZnVFWE5BVzZFQ0F6L1VmWG5WaUFua2ZpTmFnL043MitsR3FjMFVNajVURlpqNFRDek9ORTZsUQptUnhla3dmcTJPWVZrcU5GTUVNd0RnWURWUjBQQVFIL0JBUURBZ0VHTUJJR0ExVWRFd0VCL3dRSU1BWUJBZjhDCkFRRXdIUVlEVlIwT0JCWUVGSmZWRnJJem5RaTNXT1JuSFR4RWsxVEMzRWRNTUFvR0NDcUdTTTQ5QkFNQ0Ewa0EKTUVZQ0lRQzM2Mmtxdy82RnVaSHkzSW1XT3RTa0wrYWRoOC9sUktNdHlWOCtNaFNpNEFJaEFPaVlJalR0NXVsdwovN2dWWlBtRXBJRkdPdWJRZ0RPQTY3TTdFODRzazg0NAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==";
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
