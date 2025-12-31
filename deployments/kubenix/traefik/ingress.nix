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
      resources = {
        ingresses.traefik-ingress = {
          metadata = {
            name = "traefik-ingress";
            namespace = ns;
          };
          spec = {
            ingressClassName = "traefik";
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
