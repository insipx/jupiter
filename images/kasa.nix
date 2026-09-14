_: {
  perSystem =
    { pkgs, self', ... }:
    let
      kasa-exporter-image = pkgs.dockerTools.buildLayeredImage {
        name = "kasa-exporter";
        tag = "latest";
        created = "now";
        config = {
          Entrypoint = [ "${self'.packages.kasa-exporter}/bin/kasa-exporter" ];
          ExposedPorts."9101/tcp" = { };
        };
      };
    in
    {
      packages = {
        inherit kasa-exporter-image;
      };
    };
}
