{
  config,
  pkgs,
  ...
}: let
  fonts = config.stylix.fonts;

  # Noctalia's builtin `qt` template writes ONLY the palette, to
  # $XDG_CONFIG_HOME/qt{5,6}ct/colors/noctalia.conf, with no post-hook. Something
  # else has to select it -- which is why Qt was unthemed: QT_QPA_PLATFORMTHEME
  # was set, but qt5ct/qt6ct had no colour scheme configured at all.
  qtctSettings = dir: {
    Appearance = {
      style = "Fusion";
      custom_palette = true;
      color_scheme_path = "${config.xdg.configHome}/${dir}/colors/noctalia.conf";
      icon_theme = config.gtk.iconTheme.name;
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      general = ''"${fonts.sansSerif.name},${toString fonts.sizes.applications}"'';
      fixed = ''"${fonts.monospace.name},${toString fonts.sizes.terminal}"'';
    };
  };
in {
  qt = {
    enable = true;

    # styleNames has no "qt6ct" key, so QT_QPA_PLATFORMTHEME becomes the literal
    # string. Qt6 is what modern apps here use (Telegram, VLC); Qt5-only apps
    # fall back to Fusion, which is why qt5ct's colours are still written below.
    platformTheme = {
      name = "qt6ct";
      package = pkgs.qt6Packages.qt6ct;
    };

    qt6ctSettings = qtctSettings "qt6ct";
    qt5ctSettings = qtctSettings "qt5ct";
  };

  home.packages = [pkgs.libsForQt5.qt5ct];
}
