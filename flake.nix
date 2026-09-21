{
  description = "flake for managing rpi homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
    disko = {
      # the fork is needed for partition attributes support
      url = "github:nvmd/disko/gpt-attrs";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      # flake parts does not use nixpkgs
      # inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    jupiter-secrets = {
      # github: fetcher hits github.com/archive which 404s for this private
      # repo even with a valid token; git+ssh clones over SSH and works.
      # url = "git+ssh://git@github.com/insipx/jupiter-secrets";
      url = "github:insipx/jupiter-secrets";
      # url = "path:/Users/andrewplaza/code/insipx/jupiter-secrets";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    homelab = {
      # url = "github:insipx/nixos-rpi-lab";
      url = "path:/Users/andrewplaza/code/insipx/nixos-lab";
    };
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kubenix.url = "github:hall/kubenix";
    hercules-ci-agent = {
      url = "github:hercules-ci/hercules-ci-agent";
    };
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
      "https://nix-community.cachix.org"
      "https://insipx.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "insipx.cachix.org-1:JMvQq3zItXN5AO7VfPUAILAwMXQrzQ78rLoQTktWs14="
    ];
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixos-raspberrypi,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        ./scripts
        ./pkgs
        ./images
        ./hercules.nix
        ./nixos
        ./shell.nix
        ./installer-images.nix
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      perSystem =
        {
          pkgs,
          system,
          inputs',
          ...
        }:
        let
          extra = _: prev: {
            writeFishScriptBin = pkgs.callPackage ./scripts/write_fish_script { };
          };
        in
        {
          _module.args = import nixos-raspberrypi.inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.ghostty.overlays.default
              inputs.jupiter-secrets.overlays.default
              extra
              (import inputs.rust-overlay)
            ];
          };
          packages = {
            kubenix = inputs'.kubenix.packages.default.override {
              module = import ./deployments/kubenix/default.nix;
              specialArgs = {
                flake = self;
              };
            };
          };
        };
      flake = {
        lib = {
          hostname = "jupiter.lan";
          external-hostname = "insipx.xyz";
          secrets = inputs.jupiter-secrets.outPath;
        };
        colmenaHive = import ./hive { inherit inputs; };
      };
    });
}
