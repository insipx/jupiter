{ python3Packages }:

python3Packages.buildPythonApplication {
  pname = "kasa-exporter";
  version = "0.1.0";
  format = "other";

  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    python-kasa
    prometheus-client
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 kasa_exporter.py $out/bin/kasa-exporter
    runHook postInstall
  '';

  meta = {
    description = "Prometheus exporter for TP-Link Kasa devices (python-kasa; kasa-rs metric-compatible)";
    mainProgram = "kasa-exporter";
  };
}
