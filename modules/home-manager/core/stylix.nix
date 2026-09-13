{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
  ];

  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      enable = true;
      autoEnable = true;

      targets = {
        hyprland.enable = false;
        hyprland.hyprpaper.enable = false;

        starship.enable = false;
        librewolf.profileNames = ["Default"];

        gtk.enable = false;
        qt.enable = false;

        bat.enable = false;
        tmux.enable = false;
        zed.enable = false;

        fzf.enable = false;
      };
    };
}
