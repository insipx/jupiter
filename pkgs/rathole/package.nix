#lib.optionalAttrs stdenv.hostPlatform.isMusl {
#    RUSTFLAGS = "-C target-feature=+crt-static";
#    doCheck = false;
#  }
#  //

{
  craneLib,
  fetchFromGitHub,
  zlib,
  stdenv,
  lib,
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
    (
      lib.optionalAttrs stdenv.hostPlatform.isMusl {
        RUSTFLAGS = "-C target-feature=+crt-static";
      }
      //

        {
          inherit src;
          buildInputs = [ zlib ];
          cargoExtraArgs = "--no-default-features --features rustls,noise ${args}";
          strictDeps = true;
          CARGO_BUILD_TARGET = stdenv.hostPlatform.rust.rustcTarget;
        }
    );

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
in
{
  inherit client server;
}
