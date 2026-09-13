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
    rev = "a292f7ed5402f840415fc6a53827da2f34337856";
    hash = "sha256-5vhMlaPK8hOfAMu9F8Rue0q4Z1XWcxR/hnPznlXSIwQ=";
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
