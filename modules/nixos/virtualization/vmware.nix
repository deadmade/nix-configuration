{pkgs, ...}: {
  virtualisation.vmware.host.enable = true;
  virtualisation.vmware.host.package = pkgs.unstable.vmware-workstation;
}
