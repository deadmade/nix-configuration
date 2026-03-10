{pkgs, ...}: {
  environment.systemPackages = [pkgs.wayvnc];
  networking.firewall.allowedTCPPorts = [5900];
}
