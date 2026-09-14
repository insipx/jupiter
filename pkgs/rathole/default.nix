{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      commonPkgs = {
        inherit system;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };
      # we could be more clever here and use an iterator to apply a list of
      # cross systems to the packageset
      crossPkgsx86 = import inputs.nixpkgs (
        commonPkgs
        // {
          crossSystem = "x86_64-unknown-linux-musl";
        }
      );
      crossPkgsAarch64 = import inputs.nixpkgs (
        commonPkgs
        // {
          crossSystem = "aarch64-unknown-linux-musl";
        }
      );
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default);
      crossLibx86 = (inputs.crane.mkLib crossPkgsx86).overrideToolchain (
        tp:
        tp.rust-bin.stable.latest.default.override {
          targets = [
            "x86_64-unknown-linux-musl"
          ];
        }
      );
      crossLibAarch64 = (inputs.crane.mkLib crossPkgsAarch64).overrideToolchain (
        p:
        p.rust-bin.stable.latest.default.override {
          targets = [
            "aarch64-unknown-linux-musl"
          ];
        }
      );
      rathole = pkgs.callPackage ./package.nix { inherit craneLib; };
      rathole-muslX86 = crossPkgsx86.callPackage ./package.nix { craneLib = crossLibx86; };
      rathole-muslAarch64 = crossPkgsAarch64.callPackage ./package.nix { craneLib = crossLibAarch64; };
    in
    {
      packages = {
        rathole-client = rathole.client;
        rathole-server = rathole.server;

        rathole-client-muslX86 = rathole-muslX86.client;
        rathole-server-muslX86 = rathole-muslX86.server;

        rathole-client-muslAarch64 = rathole-muslAarch64.client;
        rathole-server-muslAarch64 = rathole-muslAarch64.server;
      };
    };
}
