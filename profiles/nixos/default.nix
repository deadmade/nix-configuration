{
  core = import ./core.nix;
  virtualization = import ./virtualization.nix;
  desktop = import ./desktop.nix;
  desktopAll = import ./desktop-all.nix;
  wsl = import ./wsl.nix;
}
