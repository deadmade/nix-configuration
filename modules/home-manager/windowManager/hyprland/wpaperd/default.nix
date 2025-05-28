{config, ...}: {
  home.file.".config/wallpapers" = {
    source = ../../../../../wallpapers;
    recursive = true;
  };

  services.wpaperd = {
    enable = true;
  };
}
