{ inputs, ... }:
let
  root = ./..;
in
{
  # plain `nixosSystem` already imports `inject-overlays`, and `nixos-raspberrypi.lib.nixosSystem{,Full}`
  # would apply those overlays a second time, resulting in infinite recursion in `raspberrypifw`
  flake.nixosConfigurations.rpi5Install = inputs.nixos-raspberrypi.inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.disko.nixosModules.disko
      inputs.lab-secrets.nixosModules.default
      inputs.homelab.nixosModules.default
      {
        rpiHomeLab = {
          networking = {
            hostId = "55555555"; # this should be unique per-machine
            hostName = "my-new-host"; # change before installing
            address = "10.10.10.123/22"; # change before installing
            interface = "end0"; # ensure this is the correct interface
          };
          k3s.enable = false; # install w/o k3s enabled at first
        };
        imports = [
          (root + ./base)
          (root + ./machine-specific/rpi5)
        ];
      }
    ];
    specialArgs = {
      inherit inputs;
      inherit (inputs) nixos-raspberrypi;
    };
  };
}
