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
