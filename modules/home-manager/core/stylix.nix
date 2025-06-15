{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  # This is here because without it, stylix colours can't be accessed

  stylix = {
    enable = true;
    image = ../../../wallpapers/bloodMoon.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    
    autoEnable = true;
    targets.hyprlock.enable = false;
    targets.starship.enable = false;    
  };
}
