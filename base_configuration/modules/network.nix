{
  # This is mostly portions of safe network configuration defaults that
  # nixos-images and srvos provide
  networking = {
    useNetworkd = true;
    useDHCP = false;
    # mdns
    firewall.allowedUDPPorts = [ 5353 ];
  };
  # This comment was lifted from `srvos`
  # Do not take down the network for too long when upgrading,
  # This also prevents failures of services that are restarted instead of stopped.
  # It will use `systemctl restart` rather than stopping it with `systemctl stop`
  # followed by a delayed `systemctl start`.
  systemd.services = {
    systemd-networkd.stopIfChanged = false;
    # Services that are only restarted might be not able to resolve when resolved is stopped before
    systemd-resolved.stopIfChanged = false;
  };
}
