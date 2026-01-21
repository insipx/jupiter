{ kubenix, ... }:
let
  ns = "step-issuer";
in
{
  imports = with kubenix.modules; [ k8s helm submodules ];
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
