{
  networking.firewall = {
    allowedUDPPorts = [51820]; # Clients and peers can use the same port, see listenport
  };

  networking.firewall.checkReversePath = false;
  #wiegurad setup
  # https://nixos.wiki/wiki/WireGuard
  # nmcli connection import type wireguard file thefile.conf
  # nmcli con up id NameOfTheConnection
}
