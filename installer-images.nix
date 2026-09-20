# An installer based on the `rpi5` nixos configuration minus the filesystem bits (SD-card)
{ inputs, self, ... }:
let
  inherit (inputs) nixos-raspberrypi;
  initial = self.nixosConfigurations.rpi5;
  inherit (initial.config.users.users.root.openssh.authorizedKeys) keys;

  # nixos-raspberry pi rpi5 stock installer image, with ssh keys added from 'initial' config
  rpi5-installer = nixos-raspberrypi.nixosConfigurations.rpi5-installer.extendModules {
    modules = [
      {
        users.users.root.openssh.authorizedKeys.keys = keys;
        users.users.nixos.openssh.authorizedKeys.keys = keys;
      }
    ];
  };

  # SD Image of the initial config minus filesystem, sd image instead
  initialInstall-sd = initial.extendModules {
    modules = [
      {
        imports = [ nixos-raspberrypi.nixosModules.sd-image ];
        disabledModules = [ ./machine-specific/filesystem.nix ];
      }
    ];
  };
in
{
  flake = {
    nixosConfigurations = { inherit rpi5-installer initialInstall-sd; };
    # nixos-raspberry pi rpi5 stock installer image, with ssh keys added from 'initial' config
    installerImages.rpi5 = rpi5-installer.config.system.build.sdImage;
    # SD Image of the initial config minus filesystem, sd image instead
    sdImages.initialInstall = initialInstall-sd.config.system.build.sdImage;
  };
}
