# Extra config when rpi is used as a server
{ lib, ... }:
{
  # https://github.com/nix-community/srvos/blob/fa814c65868d32f7bd4d13a87b191ace02feb7d8/nixos/common/networking.nix
  # with some options disabled

  # Allow PMTU / DHCP
  # networking.firewall.allowPing = true;

}
