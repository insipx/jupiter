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

_:

{
  # ---------------------------------------------------------------------------
  # Hercules CI Agent
  # ---------------------------------------------------------------------------

  services.hercules-ci-agent = {
    enable = true;

    # Keep low — heavy builds are delegated to nixbuild.net.
    # Local slots handle evaluation and light tasks.
    concurrentTasks = 4;

    settings = {
      clusterJoinTokenPath = "/var/lib/hercules-ci-agent/secrets/cluster-join-token.key";
      binaryCachesPath = "/var/lib/hercules-ci-agent/secrets/binary-caches.json";
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
        IdentityFile /etc/ssh/ssh_host_ed25519_key
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
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        system = "x86_64-linux";
        maxJobs = 100;
        speedFactor = 4;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "nixos-test"
          "kvm"
        ];
      }
      {
        hostName = "eu.nixbuild.net";
        sshUser = "root";
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        system = "aarch64-linux";
        maxJobs = 100;
        speedFactor = 4;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
        ];
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
