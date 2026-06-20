{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  # Home-manager is used standalone here (flake.homeConfigurations), so the
  # NixOS stylix module's homeManagerIntegration.followSystem does NOT apply.
  # The full theme must therefore be defined here as well; keep base16Scheme,
  # fonts, cursor, opacity and wallpaper in sync with
  # modules/nixos/desktop/stylix.nix.
  stylix = {
    enable = true;
    image = ../../../wallpapers/dark-waves.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    autoEnable = true;

    polarity = "dark";
    opacity = {
      terminal = 0.8;
      desktop = 0.0;
    };
    cursor.package = pkgs.unstable.bibata-cursors;
    cursor.name = "Bibata-Modern-Ice";
    cursor.size = 25;
    fonts = {
      monospace = {
        package = pkgs.unstable.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.unstable.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.unstable.montserrat;
        name = "Montserrat";
      };
    };

    targets = {
      hyprlock.enable = false;
      # Starship is themed by its own custom starship.toml palette, not Stylix.
      starship.enable = false;
      librewolf.profileNames = ["Default"];
    };
  };
}
