{ kubenix, ... }:
let
  ns = "kube-system";
in
{

  imports = with kubenix.modules;
    [ k8s submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.ihnstances.kube-system = {
    submodule = "namespaced";
    args.kubernetes = {
      resources = {
        services.traefik-ingress = {
          metadata = {
            name = "traefik-ingress";
            namespace = ns;
            annotations = {
              spec = {
                ingressClassName = "traefik";
              };
            };
          };
          spec = {
            rules = [
              {
                host = "traefik.jupiter.lan";
                http = {
                  paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                      backend = {
                        service = {
                          name = "traefik-dashboard";
                          port = {
                            number = 9000;
                          };
                        };
                      };
                    }
                  ];
                };
              }
            ];
          };
        };
      };
    };
  };
}
