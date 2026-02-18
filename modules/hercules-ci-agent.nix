# Hercules CI agent with nixbuild.net remote builders.
#
# SETUP CHECKLIST:
#   1. Add each machine's host public key to your nixbuild.net account:
#        cat /etc/ssh/ssh_host_ed25519_key.pub
#        https://app.nixbuild.net/settings/ssh-keys
#   2. Get a cluster join token from the Hercules CI dashboard and save it:
#        /var/lib/hercules-ci-agent/secrets/cluster-join-token.key
#   3. Optionally configure a binary cache:
#        /var/lib/hercules-ci-agent/secrets/binary-caches.json
#   4. Deploy: colmena apply --on @hercules-ci

{ config, ... }:

let
  nixbuildKeyPath = "/var/lib/hercules-ci-agent/secrets/nixbuild_ed25519";
in
{
  # ---------------------------------------------------------------------------
  # Hercules CI Agent
  # ---------------------------------------------------------------------------

  services.hercules-ci-agent = {
    enable = true;

    settings = {
      # Keep low — heavy builds are delegated to nixbuild.net.
      # Local slots handle evaluation and light tasks.
      concurrentTasks = 4;
    };
  };

  # ---------------------------------------------------------------------------
  # SSH key — copy the host key so the hercules-ci-agent user can read it.
  # The host key at /etc/ssh/ssh_host_ed25519_key is root-only (0600).
  # ---------------------------------------------------------------------------

  systemd.services.hercules-ci-agent-nixbuild-key = {
    description = "Copy SSH host key for hercules-ci-agent nixbuild access";
    wantedBy = [ "multi-user.target" ];
    before = [ "hercules-ci-agent.service" ];
    requiredBy = [ "hercules-ci-agent.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = toString [
        "/bin/sh" "-c"
        "install -m 0600 -o hercules-ci-agent -g hercules-ci-agent /etc/ssh/ssh_host_ed25519_key ${nixbuildKeyPath}"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # SSH — trust nixbuild.net host key, configure connection for nix-daemon
  # ---------------------------------------------------------------------------

  programs.ssh = {
    knownHosts = {
      nixbuild = {
        hostNames = [ "eu.nixbuild.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
      };
    };

    extraConfig = ''
      Host eu.nixbuild.net
        PubkeyAcceptedKeyTypes ssh-ed25519
        ServerAliveInterval 60
        IPQoS throughput
        IdentityFile ${nixbuildKeyPath}
    '';
  };

  # ---------------------------------------------------------------------------
  # Nix — remote builder configuration
  # ---------------------------------------------------------------------------

  nix = {
    distributedBuilds = true;

    settings = {
      # Let remote builders fetch their own dependencies from substituters
      # instead of uploading closures from this machine.
      builders-use-substitutes = true;

      # Allow local builds as fallback when nixbuild.net is unavailable.
      max-jobs = "auto";
    };

    buildMachines = [
      {
        hostName = "eu.nixbuild.net";
        sshUser = "root";
        sshKey = nixbuildKeyPath;
        system = "x86_64-linux";
        maxJobs = 100;
        speedFactor = 4;
        supportedFeatures = [ "benchmark" "big-parallel" "nixos-test" "kvm" ];
      }
      {
        hostName = "eu.nixbuild.net";
        sshUser = "root";
        sshKey = nixbuildKeyPath;
        system = "aarch64-linux";
        maxJobs = 100;
        speedFactor = 4;
        supportedFeatures = [ "benchmark" "big-parallel" ];
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Secrets directory permissions
  # ---------------------------------------------------------------------------

  systemd.tmpfiles.rules = [
    "d /var/lib/hercules-ci-agent/secrets 0700 hercules-ci-agent hercules-ci-agent -"
  ];
}
