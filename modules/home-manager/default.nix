{
  inputs,
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports = [
    ../../packageConfigurations/windowManager/hyprland/hyprland.nix
    ../../packageConfigurations/coding/VsCodium/VsCodium.nix
    ../../packageConfigurations/terminal/kitty/kitty.nix
    ../../packageConfigurations/terminal/tmux/tmux.nix
    ../../packageConfigurations/terminal/zsh/zsh.nix
    (import ../../packageConfigurations/brwoser/floorp/floorp.nix {inherit inputs pkgs;})
    ../../packageConfigurations/flatpak/flatpak.nix
  ];

  # Home Manager Settings
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  # Install & Configure Git
  programs.git = {
    enable = true;
    userName = gitUsername;
    userEmail = gitEmail;
  };

  # Install & Configure GitHub CLI
  programs.gh.enable = true;

  # Install & Configure btop
  # programs.btop = {
  #   enable = true;
  #   settings = {
  #     vim_keys = true;
  #   };
  # };

  # Optional, hint Electron apps to use Wayland:
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  home.packages = with pkgs; [
  ];

  # Enable Home Manager
  programs.home-manager.enable = true;
}
