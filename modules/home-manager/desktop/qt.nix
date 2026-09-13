{
  config,
  pkgs,
  ...
}: let
  fonts = config.stylix.fonts;

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

    platformTheme = {
      name = "qt6ct";
      package = pkgs.qt6Packages.qt6ct;
    };

    qt6ctSettings = qtctSettings "qt6ct";
    qt5ctSettings = qtctSettings "qt5ct";
  };

  home.packages = [pkgs.libsForQt5.qt5ct];
}
