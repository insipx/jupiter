{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (
        p:
        p.rust-bin.stable.latest.default.override {
          targets = [ "x86_64-unknown-linux-musl" ];
        }
      );

      callPackage = pkgs.lib.callPackageWith (pkgs // { inherit craneLib; });
      rathole = callPackage ./rathole.nix { };
    in
    {
      packages = {
        rathole-client = rathole.client;
        rathole-server = rathole.server;
        rathole-server-image = rathole.server-image;
        rathole-client-image = rathole.client-image;
      };
    };
}
