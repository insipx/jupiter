{
  craneLib,
  fetchFromGitHub,
  dockerTools,
  ...
}:
let

  git = fetchFromGitHub {
    owner = "rathole-org";
    repo = "rathole";
    tag = "v0.5.0";
    hash = "sha256-YfLzR1lHk+0N3YU1XTNxz+KE1S3xaiKJk0zASm6cr1s=";
  };
  src = craneLib.cleanCargoSource "${git}/";

  args =
    {
      args ? "",
    }:
    {
      inherit src;
      buildInputs = [ ];
      cargoExtraArgs = "--no-default-features --features rustls,noise ${args}";
      strictDeps = true;
    };
  cargoArtifacts = craneLib.buildDepsOnly (args { });
  client = craneLib.buildPackage (
    (args { args = "--features client"; })
    // {
      inherit cargoArtifacts;
    }
  );
  server = craneLib.buildPackage (
    (args { args = "--features server"; })
    // {
      inherit cargoArtifacts;
    }
  );

  server-musl = server.overrideAttrs (
    old:
    old
    // {
      CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
      CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
    }
  );

  client-musl = client.overrideAttrs (
    old:
    old
    // {
      CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
      CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
    }
  );
  server-image = dockerTools.buildLayeredImage {
    name = "rathole-server";
    tag = "latest";
    created = "now";
    config.entrypoint = [
      "${server-musl}/bin/rathole"
    ];
  };
  client-image = dockerTools.buildLayeredImage {
    name = "rathole-client";
    tag = "latest";
    created = "now";
    config.entrypoint = [
      "${client-musl}/bin/rathole"
    ];
  };
in
{
  inherit
    client
    server
    client-image
    server-image
    ;
}
