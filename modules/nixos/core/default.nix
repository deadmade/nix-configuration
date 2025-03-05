{
  packages = import ./packages.nix;
  themes = import ./themes.nix;
  user = import ./user.nix;
  localization = import ./localization.nix;
  security = import ./security.nix;
  stylix = import ./stylix.nix;
  firejail = import ./firejail.nix;
  grub2-bootloader = import ./grub2-bootloader.nix;
  network = import ./network.nix;
}
