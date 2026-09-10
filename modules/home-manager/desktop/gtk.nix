{
  config,
  pkgs,
  ...
}: {
  # There was no GTK module at all before: the only GTK line in the repo was a
  # bare `gtk.enable = true;` on deadPc, and everything else came from Stylix's
  # gtk target. That target is now off, because Noctalia's gtk3/gtk4 templates
  # write ~/.config/gtk-{3,4}.0/gtk.css themselves and cannot do that while
  # Home Manager owns those files as read-only store symlinks.
  #
  # Turning the target off drops more than colours, so both halves are restored
  # here explicitly:
  gtk = {
    enable = true;

    # Stylix supplied adw-gtk3 (the LIGHT variant, hardcoded). Noctalia's
    # gtk apply.sh looks for exactly "adw-gtk3-dark" via theme_exists() and
    # silently skips setting a theme when it is absent, so the package has to
    # keep being installed and the dark variant named here.
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };

    # No icon theme was set at any level, so GTK apps were falling back to bare
    # hicolor/Adwaita. Papirus-Dark is the one widely-packaged theme with near
    # complete coverage that reads correctly on a dark, recolouring desktop.
    # (Deliberately NOT papirus-icon-theme.override { color = ...; }: an unknown
    # papirus-folders colour is a build-time hard failure, and the override forces
    # a from-source rebuild of a ~250 MB theme.)
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

    font = {
      inherit (config.stylix.fonts.sansSerif) package name;
      size = config.stylix.fonts.sizes.applications;
    };

    # gtk4.theme inherits from gtk.theme, and Home Manager then writes an
    # @import into ~/.config/gtk-4.0/gtk.css -- the exact file Noctalia's gtk4
    # template needs to own. Setting it null stops HM writing that file.
    #
    # The trade is deliberate: GTK4/libadwaita apps get stock Adwaita *shape*
    # plus Noctalia's colour variables, rather than adw-gtk3's GTK4 compat
    # shim. libadwaita apps are designed against stock Adwaita shape anyway.
    gtk4.theme = null;
  };

  # Stylix's gtk target also carried Flatpak support (a flattened ~/.themes copy
  # plus a GTK_THEME override). Flatpak apps still read the gtk.css Noctalia
  # writes, so colours survive; this restores the forced theme name.
  home.sessionVariables.GTK_THEME = "adw-gtk3-dark";
}
