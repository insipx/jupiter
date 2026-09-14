_: {
  perSystem =
    { pkgs, self', ... }:
    let
      inherit (pkgs) dockerTools;
      server-image = dockerTools.buildLayeredImage {
        name = "rathole-server";
        tag = "latest";
        # buildLayeredImage defaults this to the BUILDER's arch; CI builds every
        # image on an amd64 runner, so without it the cross-built images are
        # mislabelled and the kubelet pulls the wrong binary.
        architecture = "amd64";
        config = {
          Entrypoint = [ "${self'.packages.rathole-server-muslX86}/bin/rathole" ];
          # rathole's control port: where the in-cluster client dials in.
          ExposedPorts."2333/tcp" = { };
        };
      };

      client-image = dockerTools.buildLayeredImage {
        name = "rathole-client";
        tag = "latest";
        architecture = "amd64";
        config.Entrypoint = [
          "${self'.packages.rathole-client-muslX86}/bin/rathole"
        ];
      };

      client-image-aarch64 = dockerTools.buildLayeredImage {
        name = "rathole-client";
        tag = "latest";
        architecture = "arm64";
        config.Entrypoint = [
          "${self'.packages.rathole-client-muslAarch64}/bin/rathole"
        ];
      };
    in
    {
      packages = {
        rathole-client-image-x86 = client-image;
        rathole-client-image-aarch64 = client-image-aarch64;
        rathole-server-image = server-image;
      };
    };
}
