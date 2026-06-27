{
  craneLib,
  fetchFromGitHub,
  lib,
  stdenv,
}:
let
  # insipx fork: adds a `ring` crypto feature so the exporter builds as a static
  # musl binary without aws-lc-sys's C toolchain. PR pending upstream.
  git = fetchFromGitHub {
    owner = "insipx";
    repo = "kasa-rs";
    rev = "17bf94919d7aef5265d74ef041e71d2d23943832";
    hash = "sha256-h3IcoFys6QL0Vs7wc8FOWGbfg9D5RIUeztKZ5gob5/U=";
  };
  src = craneLib.cleanCargoSource "${git}/";

  # Target is taken from the (possibly cross) package set's host platform, so
  # callPackage'ing this from a crossSystem pkgs set cross-compiles correctly —
  # crane/nixpkgs handle the toolchain + linker, no manual CARGO_BUILD_TARGET/CC.
  commonArgs = {
    inherit src;
    pname = "kasa-prometheus";
    version = "0.5.0";
    cargoExtraArgs = "-p kasa-prometheus --no-default-features --features ring";
    strictDeps = true;
    CARGO_BUILD_RUSTFLAGS = lib.optionalString stdenv.hostPlatform.isStatic "-C target-feature=+crt-static";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; })
