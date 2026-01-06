{ lib, config, ... }: {
  options = {
    rpiHomeLab = {
      networking = {
        interface = lib.mkOption {
          defaultText = lib.literalMD "interface name for ethernet";
          type = lib.types.nullOr lib.types.str;
        };
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
        agent = lib.mkOption {
          defaultText = "make this node a worker-only agent node";
          type = lib.types.bool;
          default = false;
        };
        leaderAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        longhorn = lib.mkOption {
          defaultText = "enable longhorn label for this node _note:_ does not install longhorn itself.";
          type = lib.types.bool;
          default = false;
        };
      };
    };
  };

  config = {
    systemd = {
      network.networks."50-static" = lib.mkIf (config.rpiHomeLab.networking.address != null) {
        # match the interface by name
        matchConfig.Name = config.rpiHomeLab.networking.interface;
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
    };
    networking = {
      inherit (config.rpiHomeLab.networking) hostName hostId;
    };
    services = {
      k3s = lib.mkIf config.rpiHomeLab.k3s.enable {
        inherit (config.rpiHomeLab.k3s) enable;
        role = if config.rpiHomeLab.k3s.agent then "agent" else "server";
        serverAddr = lib.mkIf (!config.rpiHomeLab.k3s.leader) config.rpiHomeLab.k3s.leaderAddress;
        clusterInit = config.rpiHomeLab.k3s.leader;
        tokenFile = config.sops.secrets.k3s_token.path;
        extraFlags = [ "--debug" ]
          ++ lib.optionals (!config.rpiHomeLab.k3s.agent) [ "--disable=servicelb" ];
        nodeLabel = lib.mkIf config.rpiHomeLab.k3s.longhorn [ "longhorn-storage=enabled" ];
      };
      # longhorn related
      openiscsi = lib.mkIf config.rpiHomeLab.k3s.longhorn {
        enable = true;
        name = "${config.networking.hostName}-initiatorhost";
      };
      # https://github.com/longhorn/longhorn/issues/2166#issuecomment-2994323945
      rpcbind.enable = config.rpiHomeLab.k3s.longhorn;
      multipath.enable = false;
    };
    # patch for nixos FHS that enables nsenter for longhorn in containers
    systemd.services.iscsid.serviceConfig = lib.mkIf config.rpiHomeLab.k3s.longhorn {
      PrivateMounts = "yes";
      BindPaths = "/run/current-system/sw/bin:/bin";
    };
    boot.supportedFilesystems = lib.mkIf config.rpiHomeLab.k3s.longhorn [
      "nfs"
    ];
    networking.firewall.allowedTCPPorts = lib.mkIf config.rpiHomeLab.k3s.enable [
      6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      9100 # node exporter
    ];
    networking.firewall.allowedUDPPorts = lib.mkIf config.rpiHomeLab.k3s.enable [
      5353
      8472 # k3s, flannel: required if using multi-node for inter-node networking
      123 # time sync
    ];
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
}
