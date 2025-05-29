{config, ...}: {
  home.file.".config/wallpapers" = {
    source = ../../../../../wallpapers;
    recursive = true;
  };

  services.wpaperd = {
    enable = true;
    settings = {
      default = {
        duration = "15m";
        mode = "center";
      };
    };
  };
}
