{ kubenix, flake, ... }:
let
  ns = "step-issuer";
in
{
  imports = with kubenix.modules; [
    k8s
    helm
    submodules
  ];
  submodules.imports = [ ../lib/namespaced.nix ];
  submodules.instances.step-issuer = {
    submodule = "namespaced";
    args.kubernetes = {
      helm.releases = {
        step-issuer = {
          chart = kubenix.lib.helm.fetch {
            repo = "https://smallstep.github.io/helm-charts";
            chart = "step-issuer";
            version = "1.9.11";
            sha256 = "sha256-r6U2PxdNmcArIPdKHfP97S5w8P5yOyEswnW2l+uwIUc=";
          };
          includeCRDs = true;
          namespace = ns;
        };
      };
      resources = {
        stepclusterissuer.step-issuer = {
          metadata = {
            namespace = ns;
            name = "step-issuer";
          };
          spec = {
            url = "https://volos.${flake.lib.hostname}";
            caBundle = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJsRENDQVRtZ0F3SUJBZ0lRWmFuMkwxSmlZaEhUcC95VWdWdUFvekFLQmdncWhrak9QUVFEQWpBb01RNHcKREFZRFZRUUtFd1ZXYjJ4dmN6RVdNQlFHQTFVRUF4TU5WbTlzYjNNZ1VtOXZkQ0JEUVRBZUZ3MHlOREV5TVRreQpNVE15TURGYUZ3MHpOREV5TVRjeU1UTXlNREZhTUNneERqQU1CZ05WQkFvVEJWWnZiRzl6TVJZd0ZBWURWUVFECkV3MVdiMnh2Y3lCU2IyOTBJRU5CTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFalBaQkszMTkKT0ZsNTZXWkcrZnVFWE5BVzZFQ0F6L1VmWG5WaUFua2ZpTmFnL043MitsR3FjMFVNajVURlpqNFRDek9ORTZsUQptUnhla3dmcTJPWVZrcU5GTUVNd0RnWURWUjBQQVFIL0JBUURBZ0VHTUJJR0ExVWRFd0VCL3dRSU1BWUJBZjhDCkFRRXdIUVlEVlIwT0JCWUVGSmZWRnJJem5RaTNXT1JuSFR4RWsxVEMzRWRNTUFvR0NDcUdTTTQ5QkFNQ0Ewa0EKTUVZQ0lRQzM2Mmtxdy82RnVaSHkzSW1XT3RTa0wrYWRoOC9sUktNdHlWOCtNaFNpNEFJaEFPaVlJalR0NXVsdwovN2dWWlBtRXBJRkdPdWJRZ0RPQTY3TTdFODRzazg0NAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==";
            provisioner = {
              name = "step-issuer";
              kid = "NrzRgy81bsuWI_lLF4s7FdPllyBkzR-btetzvvxmPIg";
              passwordRef = {
                name = "step-issuer-provisioner-password";
                key = "step-password";
                namespace = ns;
              };
            };
          };
        };
        secrets.step-issuer-provisioner-password = {
          metadata.namespace = ns;
          metadata.name = "step-issuer-provisioner-password";
          stringData = {
            step-password = "ref+sops://${flake.lib.secrets}/secrets/homelab.yaml#/step_password";
          };
        };
      };
      customTypes = {
        stepissuer = {
          attrName = "stepissuer";
          group = "certmanager.step.sm";
          version = "v1beta1";
          kind = "StepIssuer";
        };
        stepclusterissuer = {
          attrName = "stepclusterissuer";
          group = "certmanager.step.sm";
          version = "v1beta1";
          kind = "StepClusterIssuer";
        };
      };
    };
  };
}
