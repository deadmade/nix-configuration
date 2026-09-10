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

  # hyprshot duplicated Noctalia's screenshot stack (which also annotates, and
  # whose region picker is bound in config.nix), and wofi-emoji duplicated
  # Noctalia's own /emo launcher provider while rendering with stock wofi
  # styling -- programs.wofi is not enabled, so the Stylix wofi target never
  # fired and it was the one visibly off-theme surface left.
  #
  # hyprpicker was previously only reachable inside the hyprshot wrapper.
  home.packages = with pkgs; [
    hyprpicker
    # Hard runtime deps of the noctalia/mpvpaper plugin, which shells out to all
    # three: mpvpaper draws the wlr-layer-shell wallpaper surface, mpv renders
    # the picker thumbnails, and socat carries slideshow state so the picker's
    # tile highlighting tracks what is actually playing.
    mpvpaper
    mpv
    socat
    # UNDECLARED dependency. The plugin manifest lists only mpvpaper and mpv,
    # but mpvpaper_service.luau shells out to `ffmpeg` in both functions that
    # turn the playing video into a still (:236 on stop, :268 on file change),
    # and that still is what Noctalia's wallpaper -- and therefore the whole
    # theme.source = "wallpaper" palette -- is generated from. Without it the
    # palette silently keeps whatever it had: startMpvpaper:416 only adopts a
    # cached frame `if fileExists`, so a video with no cached frame changes the
    # screen and leaves the colours alone. Headless because nothing here needs
    # ffmpeg's GUI/SDL outputs; mpv already brings the codec libraries.
    ffmpeg-headless
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
