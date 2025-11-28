{ dockerTools, prometheus }: dockerTools.buildLayeredImage {
  name = "prometheus-monitoring";
  tag = "latest";
  contents = [ prometheus ];
  config = {
    Entrypoint = [ "${prometheus}/bin/prometheus" ];
    ExposedPorts = {
      "9090/tcp" = { };
    };
  };
}
