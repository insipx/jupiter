{ inputs, ... }:
let
  root = ./..;
in
{
  nixosConfigurations.x86Install = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      {
        rpiHomeLab = {
          networking = {
            hostId = "a3a7b911"; # this should be unique per-machine
            hostName = "lysithea"; # change before installing
            address = "10.10.69.51/23"; # change before installing
            interface = "enp0s31f6";
          };
          k3s.enable = false;
        };
        imports = [
          inputs.homelab.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.jupiter-secrets.nixosModules.default
          (root + ./base)
          (root + ./machine-specific/thinkcentre)
        ];
      }
    ];
    specialArgs = { inherit inputs; };
  };
}
