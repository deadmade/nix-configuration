{
  pkgs,
  inputs,
  ...
}: {
  # Home Manager Settings
  home.username = "deadmade";
  home.homeDirectory = "/home/deadmade";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
  ];

  # Optional, hint Electron apps to use Wayland
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable Home Manager
  programs.home-manager.enable = true;
}
