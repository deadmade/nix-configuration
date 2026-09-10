{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; {
  imports = [
    ./config.nix
    ./noctalia.nix
  ];

  # Home Manager Pakete
  home.packages = with pkgs; [
    hyprshot # Screenshot-Tool
    wofi-emoji
  ];

  # Noctalia's own `network` bar widget already speaks to NetworkManager, so
  # nm-applet only duplicates it in the tray. (blueman and solaar are NOT
  # duplicates -- they provide pairing/config UIs Noctalia has no equivalent for.)
  services.network-manager-applet.enable = false;

  # hyprsplit Lua library (require("hyprsplit") in config.nix). Hyprland adds
  # ~/.config/hypr to the Lua package.path, so this resolves at runtime.
  home.file.".config/hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";

  # Hyprland aktivieren und konfigurieren
  wayland.windowManager.hyprland = {
    package = pkgs.unstable.hyprland; # 0.56.2, required for the Lua config format
    enable = true;
    configType = "lua"; # Generate hyprland.lua instead of hyprland.conf
    xwayland.enable = true;
    systemd.enable = true;
  };
}
