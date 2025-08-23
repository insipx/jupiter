{ lib, config, ... }:


let
  cfg = config.rpiHomeLab;
in
{
  options = {
    rpiHomeLab = {
      lib = lib.mkOption {
        defaultText = lib.literalMD "raspberry-pi system lib setup";
      };
      inputs = lib.mkOption {
        defaultText = lib.literalMD "flake inputs";
      };
      disko = lib.mkOption {
        defaultText = lib.literalMD "disko";
      };
      networking = {
        hostId = lib.mkOption {
          defaultText = lib.literalMD "for ZFS. must be unique";
          type = lib.types.str;
        };
        hostName = lib.mkOption {
          defaultText = lib.literalMD "machine hostname";
          type = lib.types.str;
        };
      };
    };
  };

  config = {
    flake.nixosConfigurations.rpi5HomeLab = cfg.rpiHomeLab.lib.nixosSystemFull
      {
        specialArgs = cfg.rpiHomeLab.inputs;
        modules = [
          {
            networking.hostName = "${cfg.rpiHomeLab.hostName}";
          }
          ./modules/config.nix # main configuration
          # Disk configuration
          cfg.rpiHomeLab.disko.nixosModules.disko
          # WARNING: formatting disk with disko is DESTRUCTIVE, check if
          # `disko.devices.disk.nvme0.device` is set correctly!
          ./disko-nvme-zfs.nix
          { networking.hostId = "${cfg.rpiHomeLab.networking.hostId }"; }
          # Further user configuration
          # common-user-config
          {
            boot.tmp.useTmpfs = true;
          }
        ];
      };
  };
}






















