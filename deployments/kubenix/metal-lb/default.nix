{ kubenix, ... }:
let
  ns = "metalllb-system";
in
{
  imports = with kubenix.modules;
    [ k8s helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.lb = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        metallb = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://metallb.github.io/metallb";
            chart = "metallb";
            version = "0.15.3";
            sha256 = "sha256-0000000000000000000000000000000000000000000=";
          };
          namespace = ns;

        };
      };
      resources = {
        IPAddressPool.default = {
          namespace = ns;
          spec = {
            addresses = [
              "10.10.68.0/24"
            ];
          };
        };
        L2Advertisement.default = {
          namespace = ns;
          spec = { };
        };
      };
      customTypes = {
        IPAddressPool = {
          attrName = "IPAddressPool";
          group = "metallb.io";
          version = "v1beta1";
          kind = "IPAddressPool";
        };
        L2Advertisement = {
          attrName = "L2Advertisement";
          group = "metallb.io";
          version = "v1beta1";
          kind = "L2Advertisement";
        };
      };
    };
  };
}
