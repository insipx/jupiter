{
  kubenix,
  lib,
  flake,
  ...
}:
let
  ns = "personal-apps";

  actualbudget = import ./actualbudget.nix { inherit kubenix flake; };
  wealthfolio = import ./wealthfolio.nix { inherit flake; };

  apps = [
    actualbudget
    wealthfolio
  ];

  mergeAttr = attr: lib.foldl' lib.recursiveUpdate { } (map (a: a.${attr} or { }) apps);
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
      resources = mergeAttr "resources";
      helm.releases = (mergeAttr "helm").releases or { };
      customTypes = mergeAttr "customTypes";
    };
  };
}
