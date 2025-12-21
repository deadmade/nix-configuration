{pkgs, ...}: {
  # 1. Enable the Tailscale service
  services.tailscale.enable = true;

  # 2. Open the firewall for Tailscale traffic
  # This allows the Tailscale tunnel specifically, but doesn't open ports to the world.
  networking.firewall.trustedInterfaces = ["tailscale0"];

  # Optional: Allow Tailscale to discover other devices on your LAN (Subnet Routing)
  # networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # 3. Install the Tailscale CLI tool (usually included with the service, but good to be sure)
  environment.systemPackages = [pkgs.tailscale];
}
