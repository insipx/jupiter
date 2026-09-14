{ inputs, ... }:
{
  imports = [
    ./rathole
  ];
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        kasa-exporter = pkgs.callPackage ../apps/kasa-exporter { };
      };
    };

}
