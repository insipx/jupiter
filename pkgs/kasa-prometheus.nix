{
  craneLib,
  fetchFromGitHub,
  dockerTools,
  ...
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

  commonArgs = {
    inherit src;
    pname = "kasa-prometheus";
    version = "0.5.0";
    cargoExtraArgs = "-p kasa-prometheus --no-default-features --features ring";
    buildInputs = [ ];
    strictDeps = true;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  # Default glibc dynamic build (.#kasa-prometheus).
  kasa-prometheus = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });

  # Static musl build (ring backend → pure-Rust link, glibc cc is fine).
  muslArgs = commonArgs // {
    CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
    CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
  };

  kasa-prometheus-musl = craneLib.buildPackage (
    muslArgs // { cargoArtifacts = craneLib.buildDepsOnly muslArgs; }
  );

  kasa-prometheus-image = dockerTools.buildLayeredImage {
    name = "kasa-prometheus";
    tag = "latest";
    created = "now";
    config = {
      entrypoint = [ "${kasa-prometheus-musl}/bin/kasa-prometheus" ];
      ExposedPorts = {
        "9101/tcp" = { };
      };
    };
  };
in
{
  inherit
    kasa-prometheus
    kasa-prometheus-musl
    kasa-prometheus-image
    ;
}
