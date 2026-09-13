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

  home.packages = with pkgs; [
    hyprpicker

    mpvpaper
    mpv
    socat

    ffmpeg-headless

    sqlite

    ai-usagebar
  ];

  services.network-manager-applet.enable = false;

  home.file.".config/hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";

  wayland.windowManager.hyprland = {
    package = pkgs.unstable.hyprland;
    enable = true;
    configType = "lua";
    xwayland.enable = true;
    systemd.enable = true;
  };
}
