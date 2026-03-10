{
  pkgs,
  lib,
  ...
}: {
  services.tailscale.enable = true;
  networking.firewall.checkReversePath = lib.mkForce "loose";
  environment.systemPackages = [pkgs.tailscale];
}
