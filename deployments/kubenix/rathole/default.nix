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
        # The whole config is the secret, not a ConfigMap plus a token: rathole
        # has no env-var interpolation, so the shared token has to sit in the
        # file as literal text. Keep the canonical copy (both client and server
        # config) in jupiter-secrets so the two ends cannot drift.
        #
        # Must live in `resources`, not helm values -- the ref+sops:// string
        # interpolates flake.lib.secrets, a store path, and kubenix refuses to
        # let a generated manifest refer to one. stringData (not data) is what
        # vals resolves at apply time.
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
                  # rathole takes the config path positionally; the image's
                  # Entrypoint is the binary itself.
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
