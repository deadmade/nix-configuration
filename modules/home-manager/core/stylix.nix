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
    image = ../../../wallpapers/stylix/bloodMoon.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";

    autoEnable = false;

    polarity = "dark";
    opacity = {
      terminal = 0.8;
      desktop = 0.0;
    };
    cursor.package = pkgs.bibata-cursors;
    cursor.name = "Bibata-Modern-Ice";
    cursor.size = 25;
    fonts = {
      monospace = {
        package = pkgs.unstable.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
    };
  };
}
