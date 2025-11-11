{ lib, config, ... }: {
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
      secrets = {
        enable = lib.mkOption {
          defaultText = "Enable sops k3s secrets. requires a built system with a ed25519 key.";
          type = lib.types.bool;
          default = true;
        };
      };
    };
  };

  config = {
    systemd.network.networks."50-static" = lib.mkIf (config.rpiHomeLab.networking.address != null) {
      # match the interface by name
      matchConfig.Name = "end0";
      address = [
        # configure addresses including subnet mask
        config.rpiHomeLab.networking.address
      ];
      routes = [
        {
          Gateway = "10.10.69.1";
          Destination = "0.0.0.0/0";
        }
      ];
      # make the routes on this interface a dependency for network-online.target
      linkConfig.RequiredForOnline = "routable";
      dns = [ "10.10.69.1" ];
    };
    networking = {
      inherit (config.rpiHomeLab.networking) hostName hostId;
    };
    services.k3s = lib.mkIf config.rpiHomeLab.k3s.enable {
      inherit (config.rpiHomeLab.k3s) enable;
      role = "server";
      serverAddr = lib.mkIf (!config.rpiHomeLab.k3s.leader) config.rpiHomeLab.k3s.leaderAddress;
      clusterInit = lib.mkIf config.rpiHomeLab.k3s.leader true;
      tokenFile = config.sops.secrets.k3s_token.path;
      extraFlags = [ "--debug" ];
    };
    time.timeZone = "America/New_York";
    systemd.services.modprobe-vc4 = {
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      before = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      script = "/run/current-system/sw/bin/modprobe vc4";
    };
  };
  config.sops = lib.mkIf config.rpiHomeLab.secrets.enable {
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      generateKey = false;
    };
    secrets.k3s_token = {
      sopsFile = ./../secrets/homelab.yaml;
    };
  };
}
