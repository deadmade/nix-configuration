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
      #./hyprpaper/hyprpaper.nix #Testing wpaperd
      ./wpaperd/wpaperd.nix
      #./hyprpanel/hyprpanel.nix -> really strange stuff. I don't know what it is
      ./waybar/waybar.nix
      ./hyprlock/hyprlock.nix
      ./config.nix
      ./hypridle/hypridle.nix
    ];

    # Home Manager Pakete
    home.packages = with pkgs; [
      waybar # Statusleiste
      wofi # App Launcher
      dunst # Benachrichtigungen
      # hyprpaper # Wallpaper-Manager
      #wpaperd # Wallpaper-Manager Daemon
      hyprshot # Screenshot-Tool
    ];

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
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
