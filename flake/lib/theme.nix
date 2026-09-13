{pkgs}: {
  polarity = "dark";

  base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

  image = ../../wallpapers/misty-boat.jpg;

  opacity = {
    terminal = 0.8;
    desktop = 0.0;
  };

  cursor = {
    package = pkgs.unstable.bibata-cursors;

    name = "Bibata-Modern-Ice";
    size = 24;
  };

  fonts = {
    monospace = {
      package = pkgs.unstable.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
    };

    sansSerif = {
      package = pkgs.adwaita-fonts;
      name = "Adwaita Sans";
    };

    serif = {
      package = pkgs.source-serif-pro;
      name = "Source Serif Pro";
    };

    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };

    sizes = {
      applications = 11;
      desktop = 10;
      popups = 10;
      terminal = 12;
    };
  };
}
