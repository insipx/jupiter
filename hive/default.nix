{ inputs, homelabModules }:
let
  piOverride = _: prev: {
    sdl3 = (prev.sdl3.override { testSupport = false; }).overrideAttrs { doCheck = false; };
  };
in
inputs.colmena.lib.makeHive {
  meta = {
    nixpkgs = import inputs.nixos-raspberrypi.inputs.nixpkgs {
      system = "aarch64-linux";
      overlays = [
        # inputs.ghostty.overlays.default
        piOverride
        #  (_: prev: {
        #    nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystemFull;
        #  })
      ];
    };
    specialArgs = inputs;
  };
  defaults = _: {
    deployment = {
      tags = [ "homelab" ];
      targetUser = "insipx";
      buildOnTarget = false;
    };
    imports = [
      homelabModules.default
      inputs.nixos-raspberrypi.lib.inject-overlays
      inputs.disko.nixosModules.disko
      inputs.jupiter-secrets.nixosModules.default
      ./../base
    ];
    rpiHomeLab = {
      k3s.enable = true;
      k3s.leaderAddress = "https://ganymede.jupiter.lan:6443";
    };
    jupiter-secrets.enable = true;
  };
  ganymede = _: {
    imports = [
      ./../machine-specific/rpi5
    ];
    deployment = {
      targetUser = "insipx";
      targetHost = "ganymede.jupiter.lan";
    };
    rpiHomeLab = {
      networking = {
        hostId = "445ba108";
        hostName = "ganymede";
        address = "10.10.69.10/24";
        interface = "end0";
      };
    };
    rpiHomeLab.k3s.leader = true;
    services.k3s.extraFlags = [
      "--tls-san ganymede.jupiter.lan"
      "--tls-san ganymede"
      "--tls-san 10.10.69.10"
    ];
  };
  io = _: {
    imports = [
      ./../machine-specific/rpi5
    ];
    deployment = {
      targetHost = "io.jupiter.lan";
      tags = [ "workers" ];
    };
    rpiHomeLab.networking = {
      hostName = "io";
      hostId = "19454311";
      address = "10.10.69.11/24";
      interface = "end0";
    };
  };
  europa = _: {
    imports = [
      ./../machine-specific/rpi5
    ];
    deployment = {
      tags = [ "workers" ];
      targetHost = "europa.jupiter.lan";
    };
    rpiHomeLab.networking = {
      hostId = "29af5daa";
      hostName = "europa";
      address = "10.10.69.12/24";
      interface = "end0";
    };
  };
  callisto = _: {
    imports = [
      ./../machine-specific/rpi5
    ];
    deployment = {
      tags = [ "workers" ];
      targetHost = "callisto.jupiter.lan";
    };
    rpiHomeLab.networking = {
      hostId = "b0d6aebd";
      hostName = "callisto";
      address = "10.10.69.14/24";
      interface = "end0";
    };
    # callisto is the only node which is a worker
    rpiHomeLab.k3s.agent = true;
  };
  amalthea = _: {
    imports = [
      ./../machine-specific/rpi4
    ];
    deployment = {
      tags = [ "lowpower" ];
      targetHost = "amalthea.jupiter.lan";
    };
    rpiHomeLab.networking = {
      hostId = "0de35cfb";
      hostName = "amalthea";
      address = "10.10.69.15/24";
      interface = "end0";
    };
    rpiHomeLab.k3s.agent = true;
  };
  sinope = _: {
    imports = [
      ./../machine-specific/rpi3
    ];
    deployment = {
      tags = [ "lowpower" ];
      targetHost = "sinope.jupiter.lan";
    };
    rpiHomeLab.networking = {
      hostId = "0c461a51";
      hostName = "sinope";
      address = "10.10.69.16/24";
      interface = "enu1u1";
    };
    rpiHomeLab.k3s.agent = true;
  };
}
