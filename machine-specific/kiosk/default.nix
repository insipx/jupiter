{ nixos-raspberrypi, pkgs, lib, ... }: {
  imports = with nixos-raspberrypi.nixosModules; [
    ./kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    ./config.nix
    ./../sd-filesystem.nix
  ];
  environment.systemPackages = with pkgs; [
    labwc
    firefox
    wlopm
    swayidle
  ];
  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [
      "video"
      "seat"
      "input"
      "audio"
    ];
    uid = 2000;
  };
  systemd.tmpfiles.rules = [
    "d /run/user/2000 0700 kiosk users -"
  ];

  environment = {
    etc = {
      "labwc-autostart" = {
        text = ''
          #!/bin/sh

          # Wait for compositor to be ready
          sleep 2

          # Get Grafana URL - adjust for your setup
          # GRAFANA_URL="http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80"
          # DASHBOARD_ID="YOUR_DASHBOARD_ID"

          # Optional: screen power management
          ${pkgs.swayidle}/bin/swayidle -w \
            timeout 600 '${pkgs.wlopm}/bin/wlopm --off "*"' \
            resume '${pkgs.wlopm}/bin/wlopm --on "*"' &

          # Launch browser in kiosk mode
          ${pkgs.firefox}/bin/firefox \
            --kiosk \
            --private-window \
            "xmtp.org" &
            # "$GRAFANA_URL/d/$DASHBOARD_ID?kiosk&refresh=30s" &

          wait
        '';
        mode = "0755";
      };
      "labwc-rc.xml" = {
        text = ''
          <?xml version="1.0"?>
          <labwc_config>
            <core>
              <decoration>no</decoration>
            </core>

            <theme>
              <name>Clearlooks</name>
            </theme>

            <keyboard>
              <keybind key="A-F4">
                <action name="None"/>
              </keybind>
            </keyboard>
          </labwc_config>
        '';
      };
    };
  };

  services.getty.autologinUser = "kiosk";
  systemd.services.labwc-kiosk = {
    description = "jupiter homelab monitoring kiosk";
    documentation = [ "man:labwc(1)" ];
    after = [ "systemd-user-sessions.service" "network-online.target" "sound.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "graphical.target" ];

    environment = {
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "labwc";
      XDG_CURRENT_DESKTOP = "labwc";
      XDG_RUNTIME_DIR = "/run/user/2000";
      MOZ_ENABLE_WAYLAND = "1";
    };

    serviceConfig = {
      Type = "simple";
      User = "kiosk";
      PAMName = "login";

      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /run/user/2000"
        "${pkgs.coreutils}/bin/chown kiosk:users /run/user/2000"
        "${pkgs.coreutils}/bin/mkdir -p /home/kiosk/.config/labwc"
        "${pkgs.coreutils}/bin/ln -sf /etc/labwc-autostart /home/kiosk/.config/labwc/autostart"
        "${pkgs.coreutils}/bin/ln -sf /etc/labwc-rc.xml /home/kiosk/.config/labwc/rc.xml"
      ];

      ExecStart = "${lib.getBin pkgs.labwc}/bin/labwc -s";

      Restart = "on-failure";
      RestartSec = 5;

      TTYPath = "/dev/tty7";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      StandardInput = "tty";
      StandardOutput = "journal";
      StandardError = "journal";

      # Security
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      PrivateTmp = true;
    };
  };
}
