{
  # imports = [
  #   ./localization.nix
  #   ./packages.nix
  #   ./themes.nix
  #   ./user.nix
  # ];

  packages = import ./packages.nix;
  themes = import ./themes.nix;
  user = import ./user.nix;
  localization = import ./localization.nix;
  security = import ./security.nix;
  stylix = import ./stylix.nix;
  gaming = import ./gaming.nix;
  firejail = import ./firejail.nix;
}
