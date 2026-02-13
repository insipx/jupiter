{ inputs, pkgs, ... }:
{
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    ./../rpi5/kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    ./../rpi5/config.nix
    ./../sd-filesystem.nix
    ./../rpibase.nix
  ];
  environment.systemPackages = with pkgs; [
    cage
    ungoogled-chromium
    wlr-randr
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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUArrr4oix6p/bSjeuXKi2crVzsuSqSYoz//YJMsTlo cardno:14_836_775"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /run/user/2000 0700 kiosk users -"
  ];
  systemd = {
    defaultUnit = "graphical.target";
    services."getty@tty1".enable = false;
    services.cage-kiosk = {
      description = "jupiter homelab monitoring kiosk";
      documentation = [ "man:cage(1)" ];
      after = [
        "systemd-user-sessions.service"
        "network-online.target"
        "sound.target"
        "systemd-logind.service"
      ];
      before = [ "getty@tty1.service" ];
      conflicts = [ "getty@tty1.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "graphical.target" ];
      environment = {
        XDG_SESSION_TYPE = "wayland";
        XDG_RUNTIME_DIR = "/run/user/2000";
        MOZ_ENABLE_WAYLAND = "1";
        # Prevents Firefox from asking about being the default browser
        MOZ_CRASHREPORTER_DISABLE = "1";
      };
      serviceConfig = {
        Type = "simple";
        User = "kiosk";
        PAMName = "login";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p /run/user/2000"
          "${pkgs.coreutils}/bin/chown kiosk:users /run/user/2000"
        ];
        ExecStart = ''
          ${pkgs.cage}/bin/cage -- \
          ${pkgs.ungoogled-chromium}/bin/chromium \
            --kiosk \
            --incognito \
            --no-sandbox \
            --disable-dev-shm-usage \
            --disable-pinch \
            --disable-translate \
            --noerrdialogs \
            --fast-unload \
            https://grafana.jupiter.lan/playlists/play/afccjeleouq68d?kiosk=true&autofitpanels=true
        '';
        Restart = "on-failure";
        RestartSec = 5;
        TTYPath = "/dev/tty1";
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
  };
}
