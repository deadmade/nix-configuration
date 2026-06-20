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
      ./config.nix
      ./noctalia.nix
    ];

    # Home Manager Pakete
    home.packages = with pkgs; [
      hyprshot # Screenshot-Tool
      networkmanagerapplet
      wofi-emoji
    ];

    services.network-manager-applet.enable = true;

    # hyprsplit Lua library (require("hyprsplit") in config.nix). Hyprland adds
    # ~/.config/hypr to the Lua package.path, so this resolves at runtime.
    home.file.".config/hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
      package = pkgs.unstable.hyprland; # 0.55.x, required for the Lua config format
      enable = true;
      configType = "lua"; # Generate hyprland.lua instead of hyprland.conf
      xwayland.enable = true;
      systemd.enable = true;
    };
  }
