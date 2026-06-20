{
  wayland.windowManager.hyprland = {
    # Declarative parts map to hl.<name>(...) calls in the generated
    # ~/.config/hypr/hyprland.lua. Attributes with `_var` become `local`s, so
    # they are visible to the raw Lua in `extraConfig` below.
    settings = {
      mainMod._var = "SUPER";
      terminal._var = "ghostty";
      fileManager._var = "thunar";

      # All keyword-style sections live under a single hl.config({ ... }) call.
      config = {
        # Eingabe (Tastatur & Maus)
        input = {
          kb_layout = "de"; # Tastaturlayout auf Deutsch setzen
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = true;
            # tap-to-click defaults to true in Hyprland 0.55; the lua setter
            # rejects the hyphenated nested key, so it is left at the default.
          };
        };

        # Allgemeine Einstellungen
        general = {
          layout = "dwindle";
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
        };

        misc = {
          disable_hyprland_logo = true;
          always_follow_on_dnd = true;
          layers_hog_keyboard_focus = true;
          animate_manual_resizes = false;
          enable_swallow = true;
          focus_on_activate = true;
          middle_click_paste = false;
        };

        dwindle = {
          # pseudotile is a dispatcher in 0.55 (bound to SUPER+P), not a setting.
          preserve_split = true;
        };

        # Dekorationen & Effekte
        decoration = {
          rounding = 5;
        };

        # Hyprland's default animation preset matches the previous custom curves,
        # so just enable animations instead of re-declaring every hl.curve/anim.
        animations = {
          enabled = true;
        };
      };

      monitor = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];

      gesture = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];
    };

    # Raw Lua: autostart, keybindings, and the hyprsplit Lua library. This is
    # appended after the settings above, so the `mainMod`/`terminal`/`fileManager`
    # locals are in scope here.
    extraConfig = ''
      -- hyprsplit: awesome/dwm-like per-monitor workspaces (Lua library)
      local hs = require("hyprsplit")
      hs.config({ num_workspaces = 10 })

      -- Autostart
      -- noctalia is started by its systemd user service (programs.noctalia.systemd.enable),
      -- bound to graphical-session.target, so it is not exec'd here.
      hl.on("hyprland.start", function()
        hl.exec_cmd("librewolf")
      end)

      -- Keybindings
      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + C", hl.dsp.window.close())
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
      hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("librewolf"))
      hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region output --clipboard-only"))
      hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle notifications"))
      hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("wofi-emoji"))
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")) -- App launcher

      hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("noctalia msg session lock || loginctl lock-session"))
      hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("noctalia msg session lock-and-suspend || systemctl suspend"))

      -- Move focus (arrows + vim keys)
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))

      -- Switch / move-to workspaces on the current monitor (hyprsplit)
      for i = 1, 10 do
        local key = i % 10 -- 10 maps to key 0
        hl.bind(mainMod .. " + " .. key,         hs.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = false }))
      end

      -- Move window within the layout
      hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
      hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
      hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))
      hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
      hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))
    '';
  };
}
