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
      ( import ../../modules/home-manager/default.nix {inherit inputs pkgs username host;})
  ];

  home.packages = with pkgs; [
     ];

    wayland.windowManager.hyprland = {
    settings = {
      # Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
      monitor = [

      ];
    };  
    };
}
