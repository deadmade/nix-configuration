{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  # Shared with modules/home-manager/core/stylix.nix. homeConfigurations are
  # standalone, so homeManagerIntegration.followSystem never fires and the theme
  # genuinely has to exist on both sides -- but from one definition, not two.
  #
  # Note: this is deliberately NOT wrapped in a blanket lib.mkDefault. Applying
  # mkDefault to the whole attrset means any host that sets stylix.<anything>
  # replaces the entire set rather than merging into it.
  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      enable = true;
      image = ../../../wallpapers/dark-waves.jpg;
      autoEnable = true;

      targets = {
        # Re-pins the boot menu to a static Catppuccin palette at exactly the
        # moment the desktop stops being Catppuccin. Left off deliberately.
        grub.enable = false;

        # Exports QT_QPA_PLATFORMTHEME system-wide; modules/home-manager/desktop/qt.nix
        # is the single writer now.
        qt.enable = false;
      };
    };
}
