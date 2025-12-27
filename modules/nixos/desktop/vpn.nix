{pkgs, ...}: {
  networking.firewall = {
    allowedUDPPorts = [51820]; # Clients and peers can use the same port, see listenport
  };

  networking.firewall.checkReversePath = false;

  environment.systemPackages = with pkgs; [
    pkgs.unstable.protonvpn-gui
  ];
}
