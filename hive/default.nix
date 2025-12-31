{ inputs, homelabModules }:
let
  # example to override specific package
  # piOverride = _: prev: {
  #   sdl3 = (prev.sdl3.override { testSupport = false; }).overrideAttrs { doCheck = false; };
  # };
in
inputs.colmena.lib.makeHive {
  meta = {
    nixpkgs = import inputs.nixos-raspberrypi.inputs.nixpkgs {
      system = "aarch64-linux";
      overlays = [
        # inputs.ghostty.overlays.default
        #     (_: prev: {
        #       nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystemFull;
        #     })
      ];
      allowUnfree = true;
    };
    specialArgs = {
      inherit inputs homelabModules;
    };
    machinesFile = /etc/nix/machines;
  };
  ganymede = _: {
    imports = [
      ./../machine-specific/rpi5
      ./../base
    ];
    deployment = {
      targetHost = "ganymede.jupiter.lan";
      targetUser = "insipx";
      tags = [ "homelab" "mainpi" "k3s" ];
    };
    rpiHomeLab = {
      networking = {
        hostId = "445ba108";
        hostName = "ganymede";
        address = "10.10.69.10/24";
        interface = "end0";
      };
    };
    rpiHomeLab.k3s. leader = true;
    rpiHomeLab.k3s.enable = true;
    rpiHomeLab.k3s.longhorn = true;
    jupiter-secrets.settings.k3s = true;
    services.k3s.extraFlags = [
      "--tls-san ganymede.jupiter.lan"
      "--tls-san ganymede"
      "--tls-san 10.10.69.10"
    ];
  };
  io = _: {
    imports = [
      ./../machine-specific/rpi5
      ./../base
    ];
    deployment = {
      targetHost = "io.jupiter.lan";
      targetUser = "insipx";
      tags = [ "homelab" "mainpi" "k3s" ];
    };
    rpiHomeLab = {
      networking = {
        hostName = "io";
        hostId = "19454311";
        address = "10.10.69.11/24";
        interface = "end0";
      };
      k3s.longhorn = true;
      k3s.enable = true;
    };
    jupiter-secrets.settings.k3s = true;

  };
  europa = _: {
    imports = [
      ./../machine-specific/rpi5
      ./../base
    ];

    deployment = {
      tags = [ "homelab" "mainpi" "k3s" ];
      targetHost = "europa.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      networking = {
        hostId = "29af5daa";
        hostName = "europa";
        address = "10.10.69.12/24";
        interface = "end0";
      };
      k3s.enable = true;
      k3s.longhorn = true;

    };
    jupiter-secrets.settings.k3s = true;

  };
  callisto = _: {
    imports = [
      ./../machine-specific/rpi5
      ./../base
    ];
    deployment = {
      tags = [ "workers" "homelab" "mainpi" "k3s" ];
      targetHost = "callisto.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      k3s = {
        agent = true;
        enable = true;
        longhorn = true;

      };
      networking = {
        hostId = "b0d6aebd";
        hostName = "callisto";
        address = "10.10.69.14/24";
        interface = "end0";
      };
    };
    jupiter-secrets.settings.k3s = true;
  };
  #amalthea = _: {
  #  imports = [
  #    ./../machine-specific/rpi4
  #    ./../base
  #  ];
  #  deployment = {
  #    tags = [ "lowpower" "homelab" ];
  #    targetHost = "amalthea.jupiter.lan";
  #  };
  #  rpiHomeLab.networking = {
  #    hostId = "0de35cfb";
  #    hostName = "amalthea";
  #    address = "10.10.69.15/24";
  #    interface = "end0";
  #  };
  #  rpiHomeLab.k3s.agent = true;
  #  rpiHomeLab.k3s.enable = true;
  #
  #};
  sinope = _: {
    imports = [
      ./../machine-specific/rpi3
      ./../base
    ];
    jupiter-secrets.settings.k3s = true;
    deployment = {
      tags = [ "lowpower" "homelab" "k3s" "workers" ];
      targetHost = "sinope.jupiter.lan";
    };
    rpiHomeLab = {
      networking = {
        hostId = "0c461a51";
        hostName = "sinope";
        address = "10.10.69.16/24";
        interface = "enu1u1";
      };
      k3s.agent = true;
      k3s.enable = true;

    };
  };
  carme = _: {
    imports = [
      ./../machine-specific/kiosk
      ./../base
    ];
    deployment = {
      targetUser = "insipx";
      tags = [ "gui" "homelab" ];
      targetHost = "carme.jupiter.lan";
      buildOnTarget = false;
    };
    rpiHomeLab = {
      networking = {
        hostId = "5ae157ad";
        hostName = "carme";
        address = "10.10.69.17/24";
        interface = "end0";
      };
      k3s = {
        agent = false;
        enable = false;
      };
    };
  };
  volos = _: {
    imports = [
      ./../machine-specific/tinyca
      ./../base
    ];
    deployment = {
      targetUser = "insipx";
      tags = [ "tinyca" "homelab" ];
      targetHost = "volos";
      buildOnTarget = false;
    };
    rpiHomeLab = {
      networking = {
        hostId = "c3adcefb";
        hostName = "volos";
        address = "10.10.69.18/24";
        interface = "end0";
      };
      k3s = {
        enable = false;
      };
    };
  };
}
