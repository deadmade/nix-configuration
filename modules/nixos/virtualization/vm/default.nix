{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    quickemu
    spice
  ];
}
