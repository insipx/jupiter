_: {
  perSystem =
    {
      pkgs,
      self',
      inputs',
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          inputs'.nixos-anywhere.packages.default
          inputs'.colmena.packages.colmena
          # self'.packages.kubenix
          self'.packages.build_session
          pkgs.kubernetes-helm
          pkgs.sops
          pkgs.vals
          pkgs.age-plugin-yubikey
        ];
      };

    };
}
