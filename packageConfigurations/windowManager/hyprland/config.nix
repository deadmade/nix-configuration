{
    wayland.windowManager.hyprland = {
        settings = {
        # Drei Bildschirme konfigurieren (Passen die Namen mit `hyprctl monitors` an)
        monitor = [
          #"HDMI-A-1,1920x1080@60,0x0,1"    # Hauptmonitor links
          #"DP-1,2560x1440@144,1920x0,1"    # Mittlerer Monitor (Hauptbildschirm)
          #"HDMI-A-2,1920x1080@60,4480x0,1" # Rechter Monitor
        ];

        exec-once = ["hyprpaper &"]; # Programme beim Start

        # Eingabe (Tastatur & Maus)
        input = {
          kb_layout = "de"; # Tastaturlayout auf Deutsch setzen
          follow_mouse = 1;
          touchpad.natural_scroll = false; # Falls ein Touchpad genutzt wird
        };

        # Allgemeine Einstellungen
        general = {
        "$mainMod" = "SUPER";
        "$terminal" = "kitty";
        "$fileManager" = "thunar";
        "$menu" = "wofi --show drun --allow-images --no-actions";
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        border_part_of_window = false;
        no_border_on_floating = false;
        };

        plugin = {
        hyprsplit = {
          num_workspaces = 10;
        };
      };

            misc = {
        disable_hyprland_logo = true;
        always_follow_on_dnd = true;
        layers_hog_keyboard_focus = true;
        animate_manual_resizes = false;
        enable_swallow = true;
        focus_on_activate = true;
        new_window_takes_over_fullscreen = 2;
        middle_click_paste = false;
      };

            dwindle = {
        pseudotile = true;
        preserve_split = true;
      };


        # Dekorationen & Effekte
        decoration = {
          rounding = 5;
        };
        animations = {
          enabled = true;
        };

        # Keybindings
        bind = [
          "$mainMod, Q, exec, $terminal"
          "$mainMod, C, killactive,"
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
        "$mainMod, h, movefocus, l"
        "$mainMod, j, movefocus, d"
        "$mainMod, k, movefocus, u"
        "$mainMod, l, movefocus, r"

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
        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, split:movetoworkspacesilent, 1"
        "$mainMod SHIFT, 2, split:movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, split:movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, split:movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, split:movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, split:movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, split:movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, split:movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, split:movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, split:movetoworkspacesilent, 10"
        ];
      };
    };
}