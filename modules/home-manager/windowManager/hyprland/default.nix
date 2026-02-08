{
  lib,
  host,
  pkgs,
  inputs,
  ...
}: let
  inherit
    (import ../hosts/${host}/variables.nix)
    ;
in
  with lib; {
    imports = [
      #./wpaperd.nix # Disabled - using Noctalia wallpapers
      #./waybar.nix
      ./hyprlock.nix
      ./config.nix
      ./hypridle.nix
      ./noctalia.nix
      #./wlogout.nix
      #./wofi.nix
      #./swaync.nix
    ];

    # Home Manager Pakete
    home.packages = with pkgs; [
      hyprshot # Screenshot-Tool
      networkmanagerapplet
      wofi-emoji
      # noctalia-shell now managed by noctalia.nix module
    ];

    services.network-manager-applet.enable = true;

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
      package = pkgs.hyprland;
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;
      plugins = [pkgs.hyprlandPlugins.hyprsplit];
    };
  }
