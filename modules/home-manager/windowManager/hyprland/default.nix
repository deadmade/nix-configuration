{
  lib,
  host,
  pkgs,
  ...
}: let
  inherit
    (import ../hosts/${host}/variables.nix)
    ;
in
  with lib; {
    imports = [
      ./wpaperd
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
      plugins = [pkgs.unstable.hyprlandPlugins.hyprsplit];
    };
  }
