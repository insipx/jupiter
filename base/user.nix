{ config, ... }: {
  # Use less privileged nixos user
  users.users.insipx = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "docker"
      "seat"
      "input"
    ];
    # Allow the graphical user to login without password
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUArrr4oix6p/bSjeuXKi2crVzsuSqSYoz//YJMsTlo cardno:14_836_775"
    ];
  };

  users.users.root = {
    # Allow the user to log in as root without a password.
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUArrr4oix6p/bSjeuXKi2crVzsuSqSYoz//YJMsTlo cardno:14_836_775"
    ];
  };
  # Don't require sudo/root to `reboot` or `poweroff`.
  security.polkit.enable = true;

  # Allow passwordless sudo from insipx user
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "insipx" ];
      };
    };
    fail2ban = {
      enable = true;
    };
  };

  # allow nix-copy to live system
  nix.settings.trusted-users = [ "root" "insipx" ];

  # We are stateless, so just default to latest.
  system.stateVersion = config.system.nixos.release;
}
