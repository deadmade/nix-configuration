{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  # Fonts, cursor, opacity and the base16 fallback come from the shared base so
  # this and modules/nixos/desktop/stylix.nix cannot drift apart again.
  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      enable = true;
      image = ../../../wallpapers/dark-waves.jpg;
      autoEnable = true;

      targets = {
        # Stylix auto-enables hyprpaper whenever stylix.image is set, and it then
        # paints a second wallpaper layer underneath Noctalia's own on every
        # monitor (verified with `hyprctl layers`). Noctalia owns the wallpaper.
        hyprland.hyprpaper.enable = false;

        # Starship is themed by its own custom starship.toml palette, not Stylix.
        starship.enable = false;
        librewolf.profileNames = ["Default"];
      };
    };
}
