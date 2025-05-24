{config, ...}: {
  home.file.".config/wallpapers" = {
    source = ../../../../../wallpapers;
    recursive = true;
  };

  services.wpaperd = {
    enable = true;
    settings = {
      DP-3 = {
        path = "${config.xdg.configHome}/wallpapers";
        random = true;
        unique = true;
        apply-shadow = true;
      };
      DP-2 = {
        path = "${config.xdg.configHome}/wallpapers";
        random = true;
        unique = true;
        apply-shadow = true;
      };
      HDMI-A-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        random = true;
        unique = true;
        apply-shadow = true;
      };
    };
  };
}
