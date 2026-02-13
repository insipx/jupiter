{ pkgs, ... }:
{
  imports = [
    ./console.nix
    ./network.nix
    ./user.nix
  ];
  time.timeZone = "America/New_York";
  environment.systemPackages = with pkgs; [
    tree
    neovim
    htop
    ghostty.terminfo
    powertop
    sops
    efibootmgr
    cowsay
    lshw
    ntp
    cryptsetup
    lvm2
    nfs-utils
    libnfs
    lnav
    traceroute
  ];
  # Volos cert
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIBlDCCATmgAwIBAgIQZan2L1JiYhHTp/yUgVuAozAKBggqhkjOPQQDAjAoMQ4w
      DAYDVQQKEwVWb2xvczEWMBQGA1UEAxMNVm9sb3MgUm9vdCBDQTAeFw0yNDEyMTky
      MTMyMDFaFw0zNDEyMTcyMTMyMDFaMCgxDjAMBgNVBAoTBVZvbG9zMRYwFAYDVQQD
      Ew1Wb2xvcyBSb290IENBMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEjPZBK319
      OFl56WZG+fuEXNAW6ECAz/UfXnViAnkfiNag/N72+lGqc0UMj5TFZj4TCzONE6lQ
      mRxekwfq2OYVkqNFMEMwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8C
      AQEwHQYDVR0OBBYEFJfVFrIznQi3WORnHTxEk1TC3EdMMAoGCCqGSM49BAMCA0kA
      MEYCIQC362kqw/6FuZHy3ImWOtSkL+adh8/lRKMtyV8+MhSi4AIhAOiYIjTt5ulw
      /7gVZPmEpIFGOubQgDOA67M7E84sk844
      -----END CERTIFICATE-----
    ''
  ];
  services.chrony = {
    enable = true;
    enableNTS = false; # not enabled in opnsense
    servers = [
      "lab_gateway.jupiter.lan"
    ];
  };
  environment.enableAllTerminfo = true;
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };
  rpiHomeLab = {
    k3s.leaderAddress = "https://ganymede.jupiter.lan:6443";
  };
  jupiter-secrets.enable = true;
}
