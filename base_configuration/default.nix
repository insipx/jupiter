{ lib, config, ... }: {
  options = {
    rpiHomeLab = {
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
          default = null;
          type = lib.types.str;
        };
        address = lib.mkOption {
          defaultText = lib.literalMD "machine ipv4 address";
          default = null;
          type = lib.types.str;
        };
      };
    };
  };

  config = {
    networking = {
      hostName = "${config.rpiHomeLab.networking.hostName}";
      hostId = "${config.rpiHomeLab.networking.hostId }";
      interfaces = {
        "end0".ipv4.addresses = [{
          address = "${config.rpiHomeLab.networking.address}";
          prefixLength = 24;
        }];
      };
    };
    time.timeZone = "America/New_York";
    boot.tmp.useTmpfs = true;
  };
}





