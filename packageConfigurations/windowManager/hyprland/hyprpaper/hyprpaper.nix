{config, ...}: {
  home.file.".config/wallpapers" = {
    source = ../../../../wallpapers;
    recursive = true;
  };

  services.hyprpaper.enable = true;
  services.hyprpaper.settings = {
    splash = false;
    preload = "${config.xdg.configHome}/wallpapers/beautifulJapan.jpg";
    wallpaper = "DP-1,${config.xdg.configHome}/wallpapers/beautifulJapan.jpg";
  };
}
