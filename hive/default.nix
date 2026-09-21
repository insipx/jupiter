{ inputs }:
let
  commonImports = [
    inputs.disko.nixosModules.disko
    inputs.jupiter-secrets.nixosModules.default
    inputs.homelab.nixosModules.default
    ./../base
  ];
  # example to override specific package
  # piOverride = _: prev: {
  #   sdl3 = (prev.sdl3.override { testSupport = false; }).overrideAttrs { doCheck = false; };
  # };
in
inputs.colmena.lib.makeHive {
  meta =
    let
      pkgConfig = {
        system = "x86_64-linux";
        overlays = [
          # inputs.ghostty.overlays.default
          #     (_: prev: {
          #       nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystemFull;
          #     })
        ];
        config.allowUnfree = true;
      };
    in
    {
      nixpkgs = import inputs.nixos-raspberrypi.inputs.nixpkgs pkgConfig;
      # nodeNixpkgs = rpiPkgSet // x86PkgSet;
      machinesFile = /etc/nix/machines;
      specialArgs = {
        inherit inputs;
        # nixos-raspberrypi modules (raspberry-pi-5.*, nixpkgs-rpi) expect this
        # arg; upstream's lib.nixosSystem* injects it, colmena does not
        nixos-raspberrypi = inputs.nixos-raspberrypi;
      };
    };

  ganymede = _: {
    imports = [
      ./../machine-specific/rpi5
    ]
    ++ commonImports;
    deployment = {
      targetHost = "ganymede.jupiter.lan";
      targetUser = "insipx";
      tags = [
        "homelab"
        "k3s"
        "control"
      ];
    };
    rpiHomeLab = {
      networking = {
        hostId = "445ba108";
        hostName = "ganymede";
        address = "10.10.69.10/22";
        interface = "end0";
      };
    };
    rpiHomeLab.k3s.leader = true;
    rpiHomeLab.k3s.enable = true;
    rpiHomeLab.k3s.longhorn = true;
    rpiHomeLab.k3s.longhornDiskSize = "800G";

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
    ]
    ++ commonImports;
    deployment = {
      targetHost = "io.jupiter.lan";
      targetUser = "insipx";
      tags = [
        "homelab"
        "k3s"
        "control"
      ];
    };
    rpiHomeLab = {
      networking = {
        hostName = "io";
        hostId = "19454311";
        address = "10.10.69.11/22";
        interface = "end0";
      };
      k3s = {
        longhorn = true;
        longhornDiskSize = "800G";

        enable = true;
      };
    };
    jupiter-secrets.settings.k3s = true;

  };

  europa = _: {
    imports = [
      ./../machine-specific/rpi5
    ]
    ++ commonImports;

    deployment = {
      tags = [
        "homelab"
        "k3s"
        "control"
      ];
      targetHost = "europa.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      networking = {
        hostId = "29af5daa";
        hostName = "europa";
        address = "10.10.69.12/22";
        interface = "end0";
      };
      k3s = {
        enable = true;
        longhorn = true;
        longhornDiskSize = "800G";

      };
    };
    jupiter-secrets.settings.k3s = true;

  };

  callisto = _: {
    imports = [
      ./../machine-specific/rpi5
    ]
    ++ commonImports;
    deployment = {
      tags = [
        "workers"
        "homelab"
        "k3s"
      ];
      targetHost = "callisto.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      k3s = {
        agent = true;
        enable = true;
        longhorn = true;
        longhornDiskSize = "800G";

      };
      networking = {
        hostId = "b0d6aebd";
        hostName = "callisto";
        address = "10.10.69.14/22";
        interface = "end0";
      };
    };
    jupiter-secrets.settings.k3s = true;
  };

  sinope = _: {
    imports = [
      ./../machine-specific/rpi3
    ]
    ++ commonImports;
    jupiter-secrets.settings.k3s = true;
    deployment = {
      tags = [
        "lowpower"
        "homelab"
        "k3s"
        "workers"
      ];
      targetHost = "sinope.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      networking = {
        hostId = "0c461a51";
        hostName = "sinope";
        address = "10.10.69.16/22";
        interface = "enu1u1";
      };
      k3s = {
        longhorn = false;
        agent = true;
        enable = true;
      };
    };
  };

  carme = _: {
    imports = [
      ./../machine-specific/kiosk
    ]
    ++ commonImports;
    deployment = {
      targetUser = "insipx";
      tags = [
        "gui"
        "homelab"
      ];
      targetHost = "carme.jupiter.lan";
      buildOnTarget = false;
    };
    rpiHomeLab = {
      networking = {
        hostId = "5ae157ad";
        hostName = "carme";
        address = "10.10.69.17/22";
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
    ]
    ++ commonImports;
    deployment = {
      targetUser = "insipx";
      tags = [
        "tinyca"
        "homelab"
      ];
      targetHost = "volos";
      buildOnTarget = false;
    };
    rpiHomeLab = {
      networking = {
        hostId = "c3adcefb";
        hostName = "volos";
        address = "10.10.69.18/22";
        interface = "end0";
      };
      k3s = {
        enable = false;
      };
    };
  };
  elara = _: {
    imports = [
      ./../machine-specific/rpi5
    ]
    ++ commonImports;
    deployment = {
      targetUser = "insipx";
      tags = [
        "homelab"
        "workers"
      ];
      targetHost = "elara";
      buildOnTarget = false;
    };
    rpiHomeLab = {
      networking = {
        hostId = "c6c81d8d";
        hostName = "elara";
        address = "10.10.69.20/22";
        interface = "end0";
      };
      k3s = {
        enable = true;
        longhorn = true;
        agent = true;
        longhornDiskSize = "900G";
      };
    };
    jupiter-secrets.settings.k3s = true;
  };

  amalthea = _: {
    nixpkgs.system = "x86_64-linux";
    imports = [
      ./../machine-specific/thinkcentre
      # hercules-ci-agent 0.10.8 (037a7f91, upstream latest) pins
      # pkg-config nix-store <2.34, but nixpkgs now ships 2.34.8, so
      # hercules-ci-cnix-store fails to configure. Re-enable once upstream
      # relaxes the bound.
      # ./../modules/hercules-ci-agent.nix
      # inputs.hercules-ci-agent.nixosModules.agent-service
    ]
    ++ commonImports;
    deployment = {
      tags = [
        "thinkcentre"
        "homelab"
        "workers"
        "hercules-ci"
      ];
      targetHost = "amalthea.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      networking = {
        hostId = "b31fd201";
        hostName = "amalthea";
        address = "10.10.69.50/22";
        interface = "enp0s31f6";
      };
      k3s = {
        enable = true;
        agent = true;
        longhorn = true;
        longhornDiskSize = "400G";
      };
    };
    jupiter-secrets.settings.k3s = true;
  };
  lysithea = _: {
    nixpkgs.system = "x86_64-linux";
    imports = [
      ./../machine-specific/thinkcentre
      # hercules-ci-agent 0.10.8 (037a7f91, upstream latest) pins
      # pkg-config nix-store <2.34, but nixpkgs now ships 2.34.8, so
      # hercules-ci-cnix-store fails to configure. Re-enable once upstream
      # relaxes the bound.
      # ./../modules/hercules-ci-agent.nix
      # inputs.hercules-ci-agent.nixosModules.agent-service
    ]
    ++ commonImports;
    deployment = {
      tags = [
        "thinkcentre"
        "homelab"
        "workers"
        "hercules-ci"
      ];
      targetHost = "lysithea.jupiter.lan";
      targetUser = "insipx";
    };
    rpiHomeLab = {
      networking = {
        hostId = "a3a7b911";
        hostName = "lysithea";
        address = "10.10.69.51/22";
        interface = "enp0s31f6";
      };
      k3s = {
        enable = true;
        agent = true;
        longhorn = true;
        longhornDiskSize = "400G";
      };
    };
    jupiter-secrets.settings.k3s = true;
  };
}
