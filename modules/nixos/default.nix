{
  packages = import ./packages.nix;
  users = import ./user.nix;
  themes = import ./themes.nix;
  localization = import ./localization.nix;
}
