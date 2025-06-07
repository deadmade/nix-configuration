{
  wayland.windowManager.hyprland = {
    settings = {
      exec-once = [
        "wpaperd &"
        "hypridle &"
        "waybar &"
        "flatpak run vesktop --start-minimized &"
        "nm-applet --indicator &"
      ];

      "$mainMod" = "SUPER";
      "$terminal" = "kitty";
      "$fileManager" = "thunar";

      # Eingabe (Tastatur & Maus)
      input = {
        kb_layout = "de"; # Tastaturlayout auf Deutsch setzen
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
        };
      };

      gestures = {
        workspace_swipe = true;
      };

      # Allgemeine Einstellungen
      general = {
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        no_border_on_floating = false;
      };

      plugins = {
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

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];
      };

      # Keybindings
      bind = [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, P, pseudo," # dwindle
        "$mainMod, J, togglesplit," # dwindle
        "$mainMod, W, exec, librewolf" # Browser
        "$mainMod SHIFT, Q, exit, " # Currently not really working
        "$mainMod SHIFT, s, exec, hyprshot -m region"

        "$mainMod, L, exec, hyprlock --immediate"
        "$mainMod SHIFT, L, exec, hyprlock & disown && systemctl suspend" # hibernation with lockscreen

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
        "$mainMod SHIFT, 1, split:movetoworkspace, 1"
        "$mainMod SHIFT, 2, split:movetoworkspace, 2"
        "$mainMod SHIFT, 3, split:movetoworkspace, 3"
        "$mainMod SHIFT, 4, split:movetoworkspace, 4"
        "$mainMod SHIFT, 5, split:movetoworkspace, 5"
        "$mainMod SHIFT, 6, split:movetoworkspace, 6"
        "$mainMod SHIFT, 7, split:movetoworkspace, 7"
        "$mainMod SHIFT, 8, split:movetoworkspace, 8"
        "$mainMod SHIFT, 9, split:movetoworkspace, 9"
        "$mainMod SHIFT, 0, split:movetoworkspace, 10"

        # window control
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, h, movewindow, l"
        "$mainMod SHIFT, j, movewindow, d"
        "$mainMod SHIFT, k, movewindow, u"
        "$mainMod SHIFT, l, movewindow, r"
      ];

      monitor = [
        ",preferred,auto,auto"
      ];
    };
  };
}
