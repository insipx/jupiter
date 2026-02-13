{ inputs, pkgs, ... }:
{
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    ./../rpi5/kernel.nix
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    ./../rpi5/config.nix
    ./../filesystem.nix
    ./../rpibase.nix
  ];
  # Automatically log in at the virtual consoles.
  environment.systemPackages = with pkgs; [
    yubikey-manager
    go
    step-ca
    step-cli
    infnoise
    e2fsprogs
    net-tools
  ];
  environment.variables = {
    STEPPATH = "/etc/step-ca";
  };
  services = {
    getty.autologinUser = "insipx";
    infnoise.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
    pcscd.enable = true;
    # step ca service done on device according to https://smallstep.com/blog/build-a-tiny-ca-with-raspberry-pi-yubikey/
  };
  systemd.services."step-ca" = {
    description = "step-ca";
    # bindsTo = [ "dev-yubikey.device" ];
    # after = [ "dev-yubikey.device" ];
    serviceConfig = {
      User = "step";
      Group = "step";
      ExecStart = [
        ''
          /bin/sh -c '${pkgs.step-ca}/bin/step-ca /etc/step-ca/config/ca.json'
        ''
      ];
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;

      # allow binding to 443
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      SecureBits = "keep-caps";
      NoNewPrivileges = true;
    };
    wantedBy = [ "multi-user.target" ];
  };
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{PRODUCT}=="1050/407/*", TAG+="systemd", SYMLINK+="yubikey"
    ACTION=="remove", SUBSYSTEM=="usb", ENV{PRODUCT}=="1050/407/*", TAG+="systemd"
  '';

  # yubikey needs polkit rules
  security = {
    # rtkit.enable = true;
    polkit.enable = true;
    polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.debian.pcsc-lite.access_card") {
          return polkit.Result.YES;
        }
      });

      polkit.addRule(function(action, subject) {
        if (action.id == "org.debian.pcsc-lite.access_pcsc") {
          return polkit.Result.YES;
        }
      });
    '';
  };
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [
    443
  ];
  users.groups.step = { };
  users.users.step = {
    isSystemUser = true;
    group = "step";
    extraGroups = [
      "input"
      "seat"
      "wheel"
    ];
  };
}
