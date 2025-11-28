{ inputs, homelabModules }:
let
  piOverride = _: prev: {
    sdl3 = (prev.sdl3.override { testSupport = false; }).overrideAttrs { doCheck = false; };
  };
in
inputs.colmena.lib.makeHive {
  meta =
    let
      pkgs-firefox = import inputs.chaotic-nixpkgs {
        system = "aarch64-linux";
        overlays = [ inputs.chaotic.overlays.default ];
      };
      firefox-overlay = final: prev: {
        inherit (pkgs-firefox) firefox_nightly;
      };
    in
    {
      nixpkgs = import inputs.nixos-raspberrypi.inputs.nixpkgs {
        system = "aarch64-linux";
        overlays = [
          # inputs.ghostty.overlays.default
          piOverride
          firefox-overlay
          #  (_: prev: {
          #    nixosSystem = inputs.nixos-raspberrypi.lib.nixosSystemFull;
          #  })
        ];
        allowUnfree = true;
      };
      specialArgs = { inherit inputs homelabModules; };
      machinesFile = /etc/nix/machines;
    };
  ganymede = _: {
    imports = [
      ./../machine-specific/rpi5
      ./../base
    ];
    deployment = {
      targetHost = "ganymede.jupiter.lan";
      tags = [ "homelab" ];
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
      ./../base
    ];
    deployment = {
      targetHost = "io.jupiter.lan";
      tags = [ "workers" "homelab" ];
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
      ./../base
    ];
    deployment = {
      tags = [ "workers" "homelab" ];
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
      ./../base
    ];
    deployment = {
      tags = [ "workers" "homelab" ];
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
      ./../base
    ];
    deployment = {
      tags = [ "lowpower" "homelab" ];
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
      ./../base
    ];
    deployment = {
      tags = [ "lowpower" "homelab" ];
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
    rpiHomeLab.networking = {
      hostId = "5ae157ad";
      hostName = "carme";
      address = "10.10.69.17/24";
      interface = "end0";
    };
    rpiHomeLab.k3s.agent = true;
  };
}
