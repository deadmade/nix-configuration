{
  pkgs,
  lib,
  ...
}: {
  services.tailscale.enable = false;
  networking.firewall.checkReversePath = lib.mkForce "loose";
  environment.systemPackages = [pkgs.tailscale];
}
