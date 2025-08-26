{ lib, config, inputs, ... }: {
  options = {
    rpiHomeLab = {
      networking = {
        hostId = lib.mkOption {
          defaultText = lib.literalMD "for ZFS. must be unique";
          type = lib.types.nullOr lib.types.str;
        };
        hostName = lib.mkOption {
          defaultText = lib.literalMD "machine hostname";
          default = null;
          type = lib.types.nullOr lib.types.str;
        };
        address = lib.mkOption {
          defaultText = lib.literalMD "machine ipv4 address";
          default = null;
          type = lib.types.nullOr lib.types.str;
        };
      };
      k3s = {
        enable = lib.mkOption {
          defaultText = "Enable K3 config";
          type = lib.types.bool;
          default = false;
        };
        leader = lib.mkOption {
          defaultText = "Whether this represents the leaders k3s node";
          type = lib.types.bool;
          default = false;
        };
        leaderAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };
  };

  config = {
    networking = {
      inherit (config.rpiHomeLab.networking) hostName hostId;
      interfaces = lib.mkIf (config.rpiHomeLab.networking.address != null) {
        "end0".ipv4.addresses = [{
          inherit (config.rpiHomeLab.networking) address;
          prefixLength = 24;
        }];
      };
      defaultGateway.address = "10.10.69.1";
      defaultGateway.interface = "end0";
      useDHCP = false;
    };
    services.k3s = {
      inherit (config.rpiHomeLab.k3s) enable;
      role = "server";
      serverAddr = lib.mkIf (!config.rpiHomeLab.k3s.leader) config.rpiHomeLab.k3s.leaderAddress;
    };
    time.timeZone = "America/New_York";
    boot.tmp.useTmpfs = true;
  };
  imports = [
    ./modules
    ./disko-nvme-zfs.nix
  ];
}
