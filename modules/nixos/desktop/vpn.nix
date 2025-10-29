{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}: {
  networking.firewall = {
    allowedUDPPorts = [51820]; # Clients and peers can use the same port, see listenport
  };

  networking.firewall.checkReversePath = false;

  environment.systemPackages = with pkgs; [
    pkgs.unstable.protonvpn-gui
    pkgs.unstable.networkmanager-openvpn # OpenVPN plugin
    pkgs.unstable.wireguard-tools # wg utility for WireGuard :contentReference[oaicite:0]{index=1}
    pkgs.unstable.libsecret # Secret Service API
    pkgs.unstable.openvpn # the openvpn binary, if you want that backend
  ];
}
