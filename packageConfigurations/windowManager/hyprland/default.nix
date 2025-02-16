{
  lib,
  username,
  host,
  config,
  pkgs,
  ...
}: let
  inherit
    (import ../hosts/${host}/variables.nix)
    browser
    terminal
    keyboardLayout
    ;
in
  with lib; {
    imports = [
      #./hyprpaper #Testing wpaperd
      ./wpaperd
      #./hyprpanel/hyprpanel.nix -> really strange stuff. I don't know what this is
      ./waybar
      ./hyprlock
      ./config.nix
      ./hypridle
      ./wlogout
    ];

    # Home Manager Pakete
    home.packages = with pkgs; [
      waybar # Statusleiste
      wofi # App Launcher
      dunst # Benachrichtigungen
      # hyprpaper # Wallpaper-Manager
      wpaperd # Wallpaper-Manager Daemon
      hyprshot # Screenshot-Tool
      hyprlock
    ];

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
      package = pkgs.hyprland;
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;
      plugins = [pkgs.hyprlandPlugins.hyprsplit];
    };

    services.dunst = {
      enable = true;
      settings = {
        global = {
          corner_radius = 5;
        };
      };
    };
  }
