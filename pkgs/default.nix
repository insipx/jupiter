{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # craneLib for a given (possibly cross) package set: the rust toolchain
      # targets that set's own host platform, so the musl crossSystem set builds
      # static binaries with no manual CARGO_BUILD_TARGET / CC wrangling.
      craneLibFor =
        p:
        (inputs.crane.mkLib p).overrideToolchain (
          tp: tp.rust-bin.stable.latest.default.override { targets = [ tp.stdenv.hostPlatform.rust.rustcTarget ]; }
        );

      craneLib = craneLibFor pkgs;

      # rathole cross-builds musl via an in-derivation CARGO_BUILD_TARGET override,
      # so its toolchain needs that target available (unchanged from before).
      ratholeCraneLib = (inputs.crane.mkLib pkgs).overrideToolchain (
        tp: tp.rust-bin.stable.latest.default.override { targets = [ "x86_64-unknown-linux-musl" ]; }
      );
      rathole = pkgs.lib.callPackageWith (pkgs // { craneLib = ratholeCraneLib; }) ./rathole.nix { };

      callPackage = pkgs.lib.callPackageWith (pkgs // { inherit craneLib; });

      # Static musl build for THIS runner's native arch. arm64 images are built
      # on an aarch64 runner (CI matrix), so we only ever need the host arch's
      # musl crossSystem here — never a foreign-arch cross.
      muslSystem =
        {
          "x86_64-linux" = "x86_64-unknown-linux-musl";
          "aarch64-linux" = "aarch64-unknown-linux-musl";
        }
        .${system};
      muslPkgs = import inputs.nixpkgs {
        localSystem = system;
        crossSystem = muslSystem;
        overlays = [ (import inputs.rust-overlay) ];
      };
      kasa-musl = muslPkgs.callPackage ./kasa-prometheus.nix { craneLib = craneLibFor muslPkgs; };

      kasa-prometheus-image = pkgs.dockerTools.buildLayeredImage {
        name = "kasa-prometheus";
        tag = "latest";
        created = "now";
        config = {
          entrypoint = [ "${kasa-musl}/bin/kasa-prometheus" ];
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

        kasa-prometheus = callPackage ./kasa-prometheus.nix { };
        kasa-prometheus-image = kasa-prometheus-image;
      };
    };
}
