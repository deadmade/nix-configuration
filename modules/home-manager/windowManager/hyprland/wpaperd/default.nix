{
  config,
  pkgs,
  ...
}: {
  home.file.".config/wallpapers" = {
    source = ../../../../../wallpapers;
    recursive = true;
  };

  services.wpaperd = {
    enable = true;
    package = pkgs.unstable.wpaperd;
    settings = {
      default = {
        duration = "15m";
        mode = "center";
      };
    };
  };
}
