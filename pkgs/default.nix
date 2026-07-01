{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # rathole cross-builds musl via an in-derivation CARGO_BUILD_TARGET override,
      # so its toolchain needs that target available.
      ratholeCraneLib = (inputs.crane.mkLib pkgs).overrideToolchain (
        tp: tp.rust-bin.stable.latest.default.override { targets = [ "x86_64-unknown-linux-musl" ]; }
      );
      rathole = pkgs.lib.callPackageWith (pkgs // { craneLib = ratholeCraneLib; }) ./rathole.nix { };

      kasa-exporter = pkgs.callPackage ../apps/kasa-exporter { };

      kasa-exporter-image = pkgs.dockerTools.buildLayeredImage {
        name = "kasa-exporter";
        tag = "latest";
        created = "now";
        config = {
          entrypoint = [ "${kasa-exporter}/bin/kasa-exporter" ];
          ExposedPorts."9101/tcp" = { };
        };
      };
    in
    {
      packages = {
        rathole-client = rathole.client;
        rathole-server = rathole.server;
        rathole-server-image = rathole.server-image;
        rathole-client-image = rathole.client-image;

        inherit kasa-exporter kasa-exporter-image;
      };
    };
}
