{ kubenix, flake, ... }:
let
  ns = "rathole";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.${ns} = {
    submodule = "namespaced";
    args.kubernetes = {
      resources = {
        networkpolicies = import ./network-policies.nix { inherit ns; };

        secrets.rathole-client-config = {
          metadata = {
            name = "rathole-client-config";
            namespace = ns;
          };
          stringData."client.toml" =
            "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/rathole_client_config";
        };

        deployments.rathole-client = {
          metadata = {
            name = "rathole-client";
            namespace = ns;
          };
          spec = {
            replicas = 1;
            selector.matchLabels.app = "rathole-client";
            template = {
              metadata.labels.app = "rathole-client";
              spec = {
                containers.rathole-client = {
                  name = "rathole-client";
                  image = "ghcr.io/insipx/jupiter/rathole-client:latest";
                  imagePullPolicy = "Always";
                  args = [ "/etc/rathole/client.toml" ];
                  volumeMounts = [
                    {
                      name = "config";
                      mountPath = "/etc/rathole";
                      readOnly = true;
                    }
                  ];
                  resources = {
                    requests = {
                      cpu = "10m";
                      memory = "32Mi";
                    };
                    limits.memory = "128Mi";
                  };
                  securityContext = {
                    runAsNonRoot = true;
                    runAsUser = 65534;
                    readOnlyRootFilesystem = true;
                    allowPrivilegeEscalation = false;
                    capabilities.drop = [ "ALL" ];
                  };
                };
                volumes = [
                  {
                    name = "config";
                    secret.secretName = "rathole-client-config";
                  }
                ];
              };
            };
          };
        };
      };
    };
  };
}
