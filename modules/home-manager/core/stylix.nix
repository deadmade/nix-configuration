{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  # Fonts, cursor, opacity and the base16 fallback come from the shared base so
  # this and modules/nixos/desktop/stylix.nix cannot drift apart again.
  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      enable = true;
      image = ../../../wallpapers/dark-waves.jpg;
      autoEnable = true;

      targets = {
        # Noctalia's hyprland template owns the border/group colours now (it
        # renders ~/.config/hypr/noctalia.lua and config.nix require()s it), so
        # Stylix would only be writing a stale Catppuccin set underneath.
        #
        # Disabling the target also stops Stylix auto-enabling hyprpaper, which
        # it does whenever stylix.image is set and which was painting a second
        # wallpaper layer underneath Noctalia's on every monitor. The explicit
        # sub-option stays as documentation of that.
        hyprland.enable = false;
        hyprland.hyprpaper.enable = false;

        # Starship is themed by its own custom starship.toml palette, not Stylix.
        starship.enable = false;
        librewolf.profileNames = ["Default"];

        # Handed over to Noctalia, which regenerates these from the wallpaper.
        # Both targets make Home Manager own the exact files Noctalia's apply.sh
        # scripts rewrite, and those scripts die with EACCES on a store symlink.
        # modules/home-manager/desktop/{gtk,qt}.nix carry the non-colour half
        # (theme name, icon theme, fonts, platform theme) that these targets
        # were also providing.
        gtk.enable = false;
        qt.enable = false;
      };
    };
}
