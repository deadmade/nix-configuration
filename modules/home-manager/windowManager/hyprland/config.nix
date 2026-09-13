{
  vars,
  pkgs,
  ...
}: {
  wayland.windowManager.hyprland = {
    settings = {
      mainMod._var = "SUPER";
      terminal._var = vars.terminal;
      browser._var = vars.browser;

      fileManager._var = "${vars.terminal} -e yazi";

      config = {
        input = {
          kb_layout = "de";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = true;
          };
        };

        general = {
          layout = "dwindle";
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;

          gaps_workspaces = 24;
        };

        group = {
          groupbar = {
            gradients = true;
            gradient_rounding = 12;
            gradient_rounding_power = 2.4;
            gradient_round_only_edges = false;
            height = 18;
            indicator_height = 3;
            font_weight_active = 600;
            blur = true;
          };
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
          preserve_split = true;
        };

        decoration = {
          rounding = 12;
          rounding_power = 2.4;

          blur = {
            enabled = true;

            size = 6;
            passes = 3;

            popups = true;
            popups_ignorealpha = 0.2;

            new_optimizations = true;
            noise = 0.02;
            contrast = 1.0;

            brightness = 0.85;
            vibrancy = 0.25;
            vibrancy_darkness = 0.3;

            xray = true;
          };

          shadow = {
            enabled = true;

            range = 22;
            render_power = 3;
            offset = [0 6];
            scale = 0.97;

            color = "rgba(0000009a)";
            color_inactive = "rgba(00000055)";
          };

          glow = {
            enabled = true;
            range = 8;

            render_power = 4;

            color_inactive = "rgba(00000000)";
          };

          motion_blur = {
            enabled = true;
            samples = 8;
          };

          screen_shader = "${./shaders/grade.frag}";

          dim_inactive = false;

          inactive_opacity = 0.98;
          dim_special = 0.3;
          dim_around = 0.5;
        };

        animations = {
          enabled = true;
        };
      };

      gesture = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];

      curve = [
        {
          _args = [
            "emphasis"
            {
              type = "bezier";
              points = [[0.05 0.7] [0.1 1.0]];
            }
          ];
        }

        {
          _args = [
            "emphasisIn"
            {
              type = "bezier";
              points = [[0.3 0.0] [0.8 0.15]];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [[0.15 0.0] [0.1 1.0]];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [[0.5 0.5] [0.75 1.0]];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [[0.0 0.0] [1.0 1.0]];
            }
          ];
        }

        {
          _args = [
            "reveal"
            {
              type = "bezier";
              points = [[0.85 0.0] [0.15 1.0]];
            }
          ];
        }

        {
          _args = [
            "snappy"
            {
              type = "spring";

              mass = 1.0;
              stiffness = 195.0;
              dampening = 21.5;
            }
          ];
        }

        {
          _args = [
            "gentle"
            {
              type = "spring";

              mass = 1.0;
              stiffness = 124.0;
              dampening = 22.3;
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "global";
          enabled = true;
          speed = 10.0;
          bezier = "default";
        }

        {
          leaf = "windows";
          enabled = true;
          speed = 4.0;
          spring = "snappy";
        }
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 3.6;
          spring = "snappy";
          style = "popin 92%";
        }
        {
          leaf = "windowsOut";
          enabled = true;

          speed = 2.3;
          bezier = "emphasisIn";
          style = "popin 92%";
        }
        {
          leaf = "windowsMove";
          enabled = true;
          speed = 3.4;
          spring = "gentle";
        }

        {
          leaf = "border";
          enabled = true;
          speed = 4.0;
          bezier = "emphasis";
        }

        {
          leaf = "borderangle";
          enabled = true;
          speed = 100.0;
          bezier = "linear";
          style = "loop";
        }

        {
          leaf = "fade";
          enabled = true;
          speed = 2.6;
          bezier = "quick";
        }
        {
          leaf = "fadeIn";
          enabled = true;
          speed = 1.7;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeOut";
          enabled = true;
          speed = 1.4;
          bezier = "almostLinear";
        }

        {
          leaf = "layers";
          enabled = true;
          speed = 3.0;
          bezier = "emphasis";
        }
        {
          leaf = "layersIn";
          enabled = true;
          speed = 3.2;
          bezier = "emphasis";
          style = "fade";
        }
        {
          leaf = "layersOut";
          enabled = true;
          speed = 1.8;
          bezier = "emphasisIn";
          style = "fade";
        }
        {
          leaf = "fadeLayersIn";
          enabled = true;
          speed = 1.8;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeLayersOut";
          enabled = true;
          speed = 1.4;
          bezier = "almostLinear";
        }

        {
          leaf = "workspaces";
          enabled = true;
          speed = 3.2;
          spring = "gentle";
          style = "slidefade 15%";
        }
        {
          leaf = "workspacesIn";
          enabled = true;
          speed = 3.0;
          spring = "gentle";
          style = "slidefade 15%";
        }
        {
          leaf = "workspacesOut";
          enabled = true;
          speed = 2.6;
          bezier = "emphasisIn";
          style = "slidefade 15%";
        }
        {
          leaf = "specialWorkspace";
          enabled = true;
          speed = 3.0;
          spring = "gentle";
          style = "slidevert";
        }

        {
          leaf = "zoomFactor";
          enabled = true;
          speed = 7.0;
          bezier = "quick";
        }

        {
          leaf = "monitorAdded";
          enabled = true;
          speed = 40.0;
          bezier = "reveal";
        }
      ];

      layer_rule = [
        {
          match = {namespace = "^(noctalia-bar-.*)$";};
          blur = true;

          ignore_alpha = 0.25;
          animation = "slide top";
        }
        {
          match = {namespace = "^(noctalia-panel.*)$";};
          blur = true;
          ignore_alpha = 0.25;
          animation = "popin 90%";
        }
        {
          match = {namespace = "^(noctalia-attached-panel)$";};
          blur = true;
          ignore_alpha = 0.25;
          animation = "slide top";
        }
        {
          match = {namespace = "^(noctalia-notification)$";};
          blur = true;
          ignore_alpha = 0.25;
          animation = "slide right";
        }
        {
          match = {namespace = "^(noctalia-osd)$";};
          blur = true;
          ignore_alpha = 0.25;
          animation = "slide bottom";
        }
      ];

      window_rule = [
        {
          name = "fix-xwayland-drags";
          match = {
            class = "^$";
            title = "^$";
            xwayland = true;
            float = true;
            fullscreen = false;
            pin = false;
          };
          no_focus = true;
        }

        {
          name = "idle-inhibit-fullscreen";
          match = {fullscreen = true;};
          idle_inhibit = "fullscreen";
        }
        {
          name = "float-dialogs";
          match = {class = "^(pavucontrol|nm-connection-editor|\\.blueman-manager-wrapped|org\\.pulseaudio\\.pavucontrol)$";};
          float = true;
        }
        {
          name = "float-portals";
          match = {class = "^(xdg-desktop-portal-gtk)$";};
          float = true;
        }
      ];
    };

    extraConfig = ''
      function _G.noctalia_apply()
        package.loaded["noctalia"] = nil
        local ok, noctalia = pcall(function() return require("noctalia") end)
        if not ok then return end

        if noctalia.apply_theme then noctalia.apply_theme() end

        local c = noctalia.colors
        if c and c.primary and c.secondary then
          hl.config({
            general = {
              col = {
                active_border = { colors = { c.primary, c.secondary }, angle = 45 },
              },
            },
            decoration = {
              glow = {
                color = { colors = { c.primary, c.secondary }, angle = 225 },
              },
            },
          })
        end

        if c and c.surface then
          hl.config({ misc = { background_color = c.surface } })
        end
      end

      _G.noctalia_apply()

      local hs = require("hyprsplit")
      hs.config({ num_workspaces = 10 })

      local autostartSub
      autostartSub = hl.on("layer.opened", function(data)
        local ns = data and (data.namespace or data.nameSpace)
        if ns ~= "noctalia-bar-default" then return end
        if autostartSub then autostartSub:remove() end
        hl.exec_cmd(browser)
      end)

      hl.timer(function()
        if autostartSub and autostartSub:is_active() then
          autostartSub:remove()
          hl.exec_cmd(browser)
        end
      end, { timeout = 15000, type = "oneshot" })

      -- 1. Applications
      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { description = "Open terminal" })
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser), { description = "Open browser" })
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "Open file manager" })
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus"), { description = "Open Nautilus" })
      hl.bind(mainMod .. " + C", hl.dsp.window.close(), { description = "Close window" })

      -- 2. Noctalia surfaces
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"), { description = "App launcher" })
      hl.bind(mainMod .. " + X",     hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo"), { description = "Emoji picker" })
      hl.bind(mainMod .. " + A",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"), { description = "Control center" })
      hl.bind(mainMod .. " + N",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"), { description = "Notifications" })
      hl.bind(mainMod .. " + B",     hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"), { description = "Clipboard history" })
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"), { description = "Wallpaper picker" })
      hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("noctalia msg settings-toggle"), { description = "Noctalia settings" })
      hl.bind("ALT + TAB",           hl.dsp.exec_cmd("noctalia msg window-switcher"), { description = "Window switcher" })
      hl.bind(mainMod .. " + F1",    hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"), { description = "Keybind cheatsheet" })

      -- 3. Screenshots
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"), { description = "Screenshot region" })
      hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"), { description = "Screenshot and annotate" })
      hl.bind("Print",                   hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"), { description = "Screenshot full screen" })
      hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick colour" })

      -- 4. Session
      hl.bind(mainMod .. " + ESCAPE",         hl.dsp.exec_cmd("noctalia msg session lock || loginctl lock-session"), { description = "Lock session" })
      hl.bind(mainMod .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd("noctalia msg panel-toggle session"), { description = "Session menu" })
      hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Exit Hyprland" })

      -- 5. Window state
      hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
      hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudotile" })
      hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
      hl.bind(mainMod .. " + G", hl.dsp.group.toggle(), { description = "Toggle group" })
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen" })
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximise" })
      hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin(), { description = "Pin window" })

      -- 6. Mouse
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag to move window" })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Drag to resize window" })

      -- 7. Scratchpad
      hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })
      hl.bind(mainMod .. " + CTRL + S",  hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

      -- 8. Resize submap
      hl.define_submap("resize", "reset", function()
        hl.bind("h",      hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true, description = "Shrink horizontally" })
        hl.bind("l",      hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true, description = "Grow horizontally" })
        hl.bind("k",      hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true, description = "Shrink vertically" })
        hl.bind("j",      hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true, description = "Grow vertically" })
        hl.bind("left",   hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true, description = "Shrink horizontally" })
        hl.bind("right",  hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true, description = "Grow horizontally" })
        hl.bind("up",     hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true, description = "Shrink vertically" })
        hl.bind("down",   hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true, description = "Grow vertically" })
        hl.bind("escape", hl.dsp.submap("reset"), { description = "Leave resize mode" })
        hl.bind("return", hl.dsp.submap("reset"), { description = "Leave resize mode" })
      end)
      hl.bind(mainMod .. " + R", hl.dsp.submap("resize"), { description = "Resize mode" })

      -- 9. Move focus
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
      hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
      hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
      hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
      hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })

      -- 10. Monitors
      hl.bind(mainMod .. " + ALT + h", hl.dsp.focus({ monitor = "l" }), { description = "Focus monitor left" })
      hl.bind(mainMod .. " + ALT + l", hl.dsp.focus({ monitor = "r" }), { description = "Focus monitor right" })
      hl.bind(mainMod .. " + ALT + SHIFT + h", hl.dsp.window.move({ monitor = "l", follow = true }), { description = "Move window to left monitor" })
      hl.bind(mainMod .. " + ALT + SHIFT + l", hl.dsp.window.move({ monitor = "r", follow = true }), { description = "Move window to right monitor" })

      -- 11. Workspaces
      for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key,         hs.dsp.focus({ workspace = i }), { description = "Workspace " .. i })
        hl.bind(mainMod .. " + SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = true }), { description = "Move window to workspace " .. i })
      end

      -- 12. Move window
      hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
      hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
      hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })
      hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
      hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })
      hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
      hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })

      -- 13. Media and hardware keys
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"),   { locked = true, repeating = true, description = "Volume up" })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), { locked = true, repeating = true, description = "Volume down" })
      hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("noctalia msg volume-mute"), { locked = true, description = "Mute output" })
      hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("noctalia msg mic-mute"),    { locked = true, description = "Mute microphone" })

      hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("noctalia msg media toggle"),   { locked = true, description = "Play/pause" })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("noctalia msg media toggle"),   { locked = true, description = "Play/pause" })
      hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("noctalia msg media next"),     { locked = true, description = "Next track" })
      hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("noctalia msg media previous"), { locked = true, description = "Previous track" })
      hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("noctalia msg media stop"),     { locked = true, description = "Stop playback" })

      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("noctalia msg brightness-up"),   { locked = true, repeating = true, description = "Brightness up" })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true, description = "Brightness down" })
    '';
  };
}
