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
      outputs.homeManagerModules.hyprland
      outputs.homeManagerModules.coding
      outputs.homeManagerModules.browser.librewolf
      outputs.homeManagerModules.terminal
      outputs.homeManagerModules.gaming
      outputs.homeManagerModules.socialMedia.vencord
      outputs.homeManagerModules.flatpak
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core);

  home.packages = with pkgs; [
    remnote
    pkgs.unstable.p3x-onenote
    teams-for-linux
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

  services.wpaperd = {
    settings = {
      DP-3 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
      DP-2 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
      HDMI-A-1 = {
        path = "${config.xdg.configHome}/wallpapers";
        apply-shadow = true;
      };
    };
  };

  gtk = {
    enable = true;
  };

  home.shellAliases = {
 #   updateNix = "nix flake update && sudo nixos-rebuild switch --flake .#deadPc && home-manager switch --flake .#deadmade@deadPc";
  };
}
