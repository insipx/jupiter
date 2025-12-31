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
        services.traefik-dashboard = {
          metadata = {
            namespace = ns;
            labels = {
              "app.kubernetes.io/instance" = "traefik";
              "app.kubernetes.io/name" = "traefik-dashboard";
            };
          };
          spec = {
            type = "ClusterIP";
            selector = {
              "app.kubernetes.io/instance" = "traefik-kube-system";
              "app.kubernetes.io/name" = "traefik";
            };
            ports = [
              {
                port = 9000; # dashboard listens to 9000
                targetPort = 9000; # forward traffic to this port on Traefik pods
                protocol = "TCP";
                name = "traefik";
              }
            ];
          };
        };
      };
    };
  };
}
