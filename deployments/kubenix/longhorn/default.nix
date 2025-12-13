{ kubenix, ... }:
{
  imports = with kubenix.modules; [ helm submodules ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.longhorn-system = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        longhorn = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://charts.longhorn.io";
            chart = "longhorn";
            version = "1.10.1";
            sha256 = "sha256-nkS4nvFK+K7J/sE+OxOPY0nR3lkrQF5K7JM5zbXLJ0s=";
          };
          namespace = - "longhorn-system";
        };
      };
    };
  };
}
