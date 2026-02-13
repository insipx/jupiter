{
  dockerTools,
  rathole,
  writers,
}:
let
  ratholeConfig = writers.writeTOML "rathole-config.toml" {
    server = {
      bind_addr = "0.0.0.0:443";
      services = {
        my-service = {
          token = "your-token-here";
          bind_addr = "0.0.0.0:8080";
        };
      };
    };
  };
in
dockerTools.buildLayeredImage {
  name = "rathole";
  tag = "latest";
  contents = [ rathole ];
  config = {
    Entrypoint = [
      "${rathole}/bin/rathole"
      "${ratholeConfig}"
    ];
    ExposedPorts = {
      "443/tcp" = { };
    };
  };
}
