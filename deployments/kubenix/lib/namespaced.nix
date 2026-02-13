{
  config,
  kubenix,
  lib,
  name,
  args,
  ...
}:
{
  imports = with kubenix.modules; [
    submodule
    k8s
    helm
  ];

  options.submodule.args = {
    kubernetes = lib.mkOption {
      description = "Kubernetes config to be applied to a specific namespace.";
      type = lib.types.attrs;
      default = { };
    };
  };

  config = {
    submodule = {
      name = "namespaced";
      passthru.kubernetes.objects = config.kubernetes.objects;
    };

    kubernetes = lib.mkMerge [
      { namespace = name; }
      { resources.namespaces.${name} = { }; }
      args.kubernetes
    ];
  };
}
