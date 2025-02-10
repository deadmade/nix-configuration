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

      ];
    };  
    };
}
