{
  lib,
  username,
  host,
  config,
  pkgs,
  ...
}: let
  inherit
    (import ../hosts/${host}/variables.nix)
    browser
    terminal
    keyboardLayout
    ;
in
  with lib; {
    imports = [
      ./hyprpaper/hyprpaper.nix
      #./hyprpanel/hyprpanel.nix
      # ../waybar/waybar.nix
    ];

    # Home Manager Pakete
    home.packages = with pkgs; [
      waybar # Statusleiste
      alacritty # Terminal
      wofi # App Launcher
      dunst # Benachrichtigungen
      hyprpaper # Wallpaper-Manager
      pipewire # Audio
      pavucontrol # Audio-Kontrolle
    ];

    # Hyprland aktivieren und konfigurieren
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
        monitor = [
          #"HDMI-A-1,1920x1080@60,0x0,1"    # Hauptmonitor links
          #"DP-1,2560x1440@144,1920x0,1"    # Mittlerer Monitor (Hauptbildschirm)
          #"HDMI-A-2,1920x1080@60,4480x0,1" # Rechter Monitor
        ];

        "$mainMod" = "SUPER";
        "$terminal" = "kitty";
        "$fileManager" = "thunar";

        exec-once = ["hyprpaper &" "hyprpanel &"]; # Programme beim Start

        # Eingabe (Tastatur & Maus)
        input = {
          kb_layout = "de"; # Tastaturlayout auf Deutsch setzen
          follow_mouse = 1;
          touchpad.natural_scroll = false; # Falls ein Touchpad genutzt wird
        };

        # Allgemeine Einstellungen
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "rgb(00ff00)";
        };

        # Dekorationen & Effekte
        decoration = {
          rounding = 5;
        };
        animations = {
          enabled = true;
          bezier = ["myBezier, 0.05, 0.9, 0.1, 1.05"];
          animation = ["windows, 1, 4, myBezier" "fade, 1, 3, default"];
        };

        # Keybindings
        bind = [
          "$mainMod, Q, exec, $terminal"
          "$mainMod, C, killactive,"
          "$mainMod, M, exit,"
          "$mainMod, E, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod, R, exec, $menu"
          "$mainMod, P, pseudo," # dwindle
          "$mainMod, J, togglesplit," # dwindle
          "$mainMode, W, exec, floorp"

          # Move focus with mainMod + arrow keys
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"

          # Switch workspaces with mainMod + [0-9]
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"
        ];
      };
    };
  }
