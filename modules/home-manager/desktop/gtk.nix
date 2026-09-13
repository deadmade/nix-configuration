{
  config,
  pkgs,
  ...
}: {
  gtk = {
    enable = true;

    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

    font = {
      inherit (config.stylix.fonts.sansSerif) package name;
      size = config.stylix.fonts.sizes.applications;
    };

    gtk4.theme = null;
  };

  home.sessionVariables.GTK_THEME = "adw-gtk3-dark";
}
