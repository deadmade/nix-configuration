{
  lib,
  username,
  host,
  config,
  pkgs,
  inputs,
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
      ./wpaperd
      #./hyprpanel/hyprpanel.nix -> really strange stuff. I don't know what this is
      ./waybar
      ./hyprlock
      ./config.nix
      ./hypridle
      ./wlogout
      ./wofi
      ./swaync
    ];

    # Home Manager Pakete
    home.packages = with pkgs.unstable; [
      hyprshot # Screenshot-Tool
      networkmanagerapplet
      wofi-emoji
    ];

    services.network-manager-applet.enable = true;

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
      package = pkgs.unstable.hyprland;
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;
      plugins = [pkgs.hyprlandPlugins.hyprsplit];
    };
  }
