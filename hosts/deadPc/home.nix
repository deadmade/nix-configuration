{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  host,
  ...
}: {
  imports =
    [
    ]
    ++ (builtins.attrValues outputs.homeManagerModules);

  home.packages = with pkgs; [
    remnote
    pkgs.unstable.texlive.combined.scheme-full
  ];

  wayland.windowManager.hyprland = {
    settings = {
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an) -> umgedreht geht es. KP why
      monitor = [
        "DP-3, 1920x1080@60,0x0,1" # Linker Monitor
        "DP-2, 1920x1080@240,1920x0,1" # Mittlerer Monitor
        "HDMI-A-1,1920x1080@60,3840x0,1" # Rechter Monitor
      ];
    };
  };
}
