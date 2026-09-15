{ ns }:
{
  # This namespace terminates reverse proxy tunnel from the internet.
  default-deny = {
    metadata = {
      name = "default-deny";
      namespace = ns;
    };
    spec = {
      podSelector = { };
      policyTypes = [
        "Ingress"
        "Egress"
      ];
    };
  };

  allow-dns = {
    metadata = {
      name = "allow-dns";
      namespace = ns;
    };
    spec = {
      podSelector = { };
      policyTypes = [ "Egress" ];
      egress = [
        {
          to = [
            {
              namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "kube-system";
              podSelector.matchLabels."k8s-app" = "kube-dns";
            }
          ];
          ports = [
            {
              protocol = "UDP";
              port = 53;
            }
            {
              protocol = "TCP";
              port = 53;
            }
          ];
        }
      ];
    };
  };

  # pin to fly.io gateway
  allow-fly-control = {
    metadata = {
      name = "allow-fly-control";
      namespace = ns;
    };
    spec = {
      podSelector = { };
      policyTypes = [ "Egress" ];
      egress = [
        {
          to = [ { ipBlock.cidr = "168.220.82.65/32"; } ];
          ports = [
            {
              protocol = "TCP";
              port = 2333;
            }
          ];
        }
      ];
    };
  };

  # allow traefik via metallb load balancer IP
  allow-traefik-public = {
    metadata = {
      name = "allow-traefik-public";
      namespace = ns;
    };
    spec = {
      podSelector = { };
      policyTypes = [ "Egress" ];
      egress = [
        {
          to = [ { ipBlock.cidr = "10.10.70.0/24"; } ];
          ports = [
            {
              protocol = "TCP";
              port = 8445;
            }
            {
              protocol = "TCP";
              port = 80;
            }
          ];
        }
      ];
    };
  };
}
