{ ... }: {
  perSystem = { pkgs, ... }: {
    packages = {
      build_session = pkgs.callPackage ./build_session { };
      launch_instance = pkgs.callPackage ./launch_instance { };
      launch_instance_on_demand = pkgs.callPackage ./launch_instance_on_demand { };
    };
  };
}
