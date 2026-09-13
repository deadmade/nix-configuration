{pkgs, ...}: {
  networking.firewall = {
    allowedUDPPorts = [51820];
  };

  networking.firewall.checkReversePath = false;

  environment.systemPackages = with pkgs; [
    pkgs.unstable.proton-vpn
    pkgs.unstable.proton-vpn-cli
    pkgs.unstable.networkmanager-openvpn
    pkgs.unstable.wireguard-tools
    pkgs.unstable.libsecret
    pkgs.unstable.openvpn
  ];
}
