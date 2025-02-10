{
  inputs,
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports = [
      ../../modules/home-manager/default.nix
  ];

  home.packages = with pkgs; [
    remnote
    texlive.combined.scheme-full
  ];

    wayland.windowManager.hyprland = {
    settings = {
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
      monitor = [
        "DP-1,1920x1080@60,auto-left,1" # Linker Monitor (DP-1)
        "HDMI-A-1,1920x1080@60,auto,1" # Mittlerer Monitor (HDMI-A-1)
        "DP-2,1920x1080@60,auto-right,1" # Rechter Monitor (DP-2)
      ];
    };  
    };
}
{
  inputs,
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../variables.nix) gitUsername gitEmail;
in {
  imports = [
      ../../modules/home-manager/default.nix
  ];

  home.packages = with pkgs; [
    remnote
    texlive.combined.scheme-full
  ];

    wayland.windowManager.hyprland = {
    settings = {
      # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
      monitor = [
        "DP-1,1920x1080@60,auto-left,1" # Linker Monitor (DP-1)
        "HDMI-A-1,1920x1080@60,auto,1" # Mittlerer Monitor (HDMI-A-1)
        "DP-2,1920x1080@60,auto-right,1" # Rechter Monitor (DP-2)
      ];
    };  
    };
}
