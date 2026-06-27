{ kubenix, flake, ... }:
let
  ns = "monitoring";
  # The offline admin token JSON the chart expects under key admin-token.json.
  # The raw token is resolved from sops; we wrap it in the offline-token schema.
  adminTokenJson = builtins.toJSON {
    token = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/influxdb3_admin_token";
    name = "admin";
    description = "homelab admin";
  };
in
{
  helm.releases.influxdb3-core = {
    chart = kubenix.lib.helm.fetch {
      repo = "https://helm.influxdata.com/";
      chart = "influxdb3-core";
      version = "0.1.0";
      sha256 = "sha256-ZpFXOsfwFPeLyF8Nb6S+GSwlQWjnWeuYndCxt5eR3mw=";
    };
    namespace = ns;
    values = {
      objectStorage = {
        type = "file";
        file.persistence = {
          storageClass = "longhorn-static";
          size = "100Gi";
          accessMode = "ReadWriteOnce";
        };
      };
      security.auth.adminToken.existingSecret = "influxdb3-admin-token";
      dataLifecycle.hardDeleteDefaultDuration = "365d";
    };
  };

  resources.secrets.influxdb3-admin-token = {
    metadata.namespace = ns;
    metadata.name = "influxdb3-admin-token";
    stringData."admin-token.json" = adminTokenJson;
  };
}
