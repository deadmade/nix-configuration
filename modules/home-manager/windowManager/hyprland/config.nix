{vars, ...}: {
  wayland.windowManager.hyprland = {
    # Declarative parts map to hl.<name>(...) calls in the generated
    # ~/.config/hypr/hyprland.lua. Attributes with `_var` become `local`s, so
    # they are visible to the raw Lua in `extraConfig` below.
    settings = {
      mainMod._var = "SUPER";
      terminal._var = vars.terminal;
      browser._var = vars.browser;
      # thunar was never installed on either host, so SUPER+E was a dead bind.
      # yazi in a terminal suits a tmux-heavy workflow better than a GTK file
      # manager; nautilus stays available on SHIFT+E for drag-and-drop.
      fileManager._var = "${vars.terminal} -e yazi";

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
          # Matches the Noctalia bar's own radius (12) so window corners and bar
          # corners read as one system. rounding_power > 2 turns the corner from
          # a circular arc into a squircle; 2.4 is the point where it reads
          # deliberate rather than merely round.
          rounding = 12;
          rounding_power = 2.4;

          blur = {
            enabled = true;
            # Passes cost exponentially more than size, but size alone smears
            # rather than blurs. 6/3 is the point where the bar reads as frosted
            # glass; on a 3070 at 5760x1080 this is not close to a bottleneck.
            size = 6;
            passes = 3;

            # popups was FALSE, which is why every menu and tooltip looked flat
            # while windows behind them were blurred.
            popups = true;
            popups_ignorealpha = 0.2;

            new_optimizations = true;
            noise = 0.02;
            contrast = 1.0;
            # Darken the blur slightly so light wallpapers do not wash out the
            # bar text on a dark palette.
            brightness = 0.85;
            vibrancy = 0.25;
            vibrancy_darkness = 0.3;
          };

          shadow = {
            enabled = true;
            # Stock was range 4 with no offset, i.e. a faint halo. A real
            # elevation shadow needs a wide, soft, DOWNWARD cast.
            range = 22;
            render_power = 3;
            offset = [0 6];
            scale = 0.97;
            # Deliberately neutral black rather than a palette tint: a coloured
            # shadow reads as a glow, not as depth.
            color = "rgba(0000009a)";
            color_inactive = "rgba(00000055)";
          };

          # dim_inactive is NOT enabled: on three monitors only one window can be
          # focused, so it would permanently dim two thirds of the desktop.
          dim_inactive = false;
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

      # settings.<name> renders as hl.<name>(...), one call per list element.
      # `curve` is in the module's importantPrefixes, so these are emitted before
      # the animations that reference them regardless of alphabetical order.
      #
      # Every curve referenced below is defined here: Hyprland's shipped default
      # config declares its own preset in a file we do not load, so names like
      # easeOutQuint are NOT available to us for free.
      curve = [
        # Material 3 "emphasized": almost all of the travel happens early, then a
        # long settle. This is what makes motion read as expensive rather than
        # merely fast.
        {
          _args = [
            "emphasis"
            {
              type = "bezier";
              points = [[0.05 0.7] [0.1 1.0]];
            }
          ];
        }
        # Its accelerating counterpart, for things leaving the screen.
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

        # Spring physics -- real mass and damping rather than a fixed cubic. This
        # is the primitive that separates a 2026 rice from a 2022 one, and the
        # stock preset already uses it for two leaves.
        # dampening below critical (2*sqrt(mass*stiffness) ~= 36 here) gives a
        # slight, deliberate overshoot on window open.
        {
          _args = [
            "snappy"
            {
              type = "spring";
              mass = 1.0;
              stiffness = 330.0;
              dampening = 28.0;
            }
          ];
        }
        # Critically damped: no overshoot, for large surfaces where a bounce
        # would read as sloppy.
        {
          _args = [
            "gentle"
            {
              type = "spring";
              mass = 1.0;
              stiffness = 210.0;
              dampening = 29.0;
            }
          ];
        }
      ];

      # speed is in deciseconds (1.0 = 100ms).
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
          speed = 1.8;
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
        # The animated gradient border. Disabled by the stock preset; "loop"
        # rotates the gradient angle continuously. 100 deciseconds = one full
        # 10s revolution, slow enough to read as a sheen rather than a spinner.
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

        # Layer surfaces are the Noctalia bar and panels; per-namespace slide
        # directions are set in the layer rules below.
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
      ];

      # The repo had ZERO layer rules, which is why the bar and every panel were
      # unblurred: Hyprland does not blur layer surfaces unless told to.
      # noctalia-wallpaper is deliberately excluded -- blurring the wallpaper
      # layer would both look wrong and waste a full-screen blur pass per monitor.
      layer_rule = [
        {
          match = {namespace = "^(noctalia-bar-.*)$";};
          blur = true;
          # Skip blurring pixels below this alpha. The bar rail is 0.40, so it
          # blurs; fully transparent gaps between capsules do not.
          # If the bar comes out unblurred, bisect this: 0.25 -> 0.0 -> remove.
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
        # Copied verbatim from Hyprland's own shipped hyprland.lua: fixes drags
        # from XWayland windows. Note the key is `pin`, not `pinned`.
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
        # Keep films and games awake -- there is now an idle ladder that would
        # otherwise lock the screen mid-playback.
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

    # Raw Lua: autostart, keybindings, and the hyprsplit Lua library. This is
    # appended after the settings above, so the `mainMod`/`terminal`/`fileManager`
    # locals are in scope here.
    extraConfig = ''
      -- Noctalia colour handoff. Noctalia's theme template renders
      -- ~/.config/hypr/noctalia.lua from the current wallpaper and then runs an
      -- apply.sh that wants to append an include line to THIS file -- which is a
      -- read-only /nix/store symlink, so that append would fail EACCES and kill
      -- the whole post-hook.
      --
      -- Its guard is `grep -qF 'require("noctalia")'`, a FIXED-STRING match, so
      -- the literal require("noctalia") below is what makes apply.sh a no-op.
      -- Do not rewrite it as pcall(require, "noctalia"): that form does not
      -- contain the literal substring and the guard would miss.
      --
      -- pcall because noctalia.lua does not exist until the first palette render.
      --
      -- Wrapped in a global so hooks.colors_changed can re-run exactly this,
      -- rather than `hyprctl reload`, which would re-run hyprsplit's setup and
      -- re-register every keybind.
      function _G.noctalia_apply()
        package.loaded["noctalia"] = nil
        local ok, noctalia = pcall(function() return require("noctalia") end)
        if not ok then return end

        if noctalia.apply_theme then noctalia.apply_theme() end

        -- The template only ever sets a FLAT border colour. Rebuild it as a
        -- two-stop gradient from the same generated palette, so the animated
        -- borderangle has something to rotate through and the sheen tracks the
        -- wallpaper. noctalia.colors.* are already "rgb(rrggbb)" strings.
        --
        -- NOTE: the Lua setter does NOT take hyprlang's "col1 col2 45deg"
        -- string form -- that errors with `invalid color`. HL.Gradient is
        -- string|{colors:string[], angle?:number}, so a gradient is a table.
        local c = noctalia.colors
        if c and c.primary and c.secondary then
          hl.config({
            general = {
              col = {
                active_border = { colors = { c.primary, c.secondary }, angle = 45 },
              },
            },
          })
        end
      end

      _G.noctalia_apply()

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
      --
      -- NOTE: Hyprland keysyms are case-insensitive and it fires EVERY matching
      -- bind. The previous map had `SUPER + L` (lock) alongside `SUPER + l`
      -- (focus right) and `SUPER + J` (togglesplit) alongside `SUPER + j`
      -- (focus down), so both of those keys ran two dispatchers at once.
      -- Anything sharing a letter with the hjkl block now lives elsewhere.

      -- Applications
      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus"))
      hl.bind(mainMod .. " + C", hl.dsp.window.close())

      -- Noctalia surfaces. Every one of these was running but unbound.
      -- Panel ids are: clipboard, control-center, launcher, polkit, session,
      -- setup-wizard, test, tray-drawer, wallpaper. "notifications" is NOT a
      -- panel -- it is a control-center tab, which is why the old
      -- `panel-toggle notifications` bind did nothing at all.
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
      hl.bind(mainMod .. " + X",     hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo"))
      hl.bind(mainMod .. " + A",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
      hl.bind(mainMod .. " + N",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"))
      hl.bind(mainMod .. " + B",     hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"))
      hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("noctalia msg settings-toggle"))
      hl.bind("ALT + TAB",           hl.dsp.exec_cmd("noctalia msg window-switcher"))

      -- Screenshots: Noctalia's own stack, which also does annotation.
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
      hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"))
      hl.bind("Print",                   hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
      hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

      -- Session. Moved off L, which collided with focus-right.
      hl.bind(mainMod .. " + ESCAPE",         hl.dsp.exec_cmd("noctalia msg session lock || loginctl lock-session"))
      hl.bind(mainMod .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))
      hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

      -- Window state. togglesplit moved off J, which collided with focus-down.
      hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
      hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))
      hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
      hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin())

      -- Mouse: SUPER + drag to move/resize. This was simply not possible before.
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Scratchpad
      hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
      hl.bind(mainMod .. " + CTRL + S",  hl.dsp.window.move({ workspace = "special:magic" }))

      -- Resize submap: SUPER+R then hjkl/arrows, ESCAPE to leave.
      hl.define_submap("resize", "reset", function()
        hl.bind("h",      hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
        hl.bind("l",      hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
        hl.bind("k",      hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
        hl.bind("j",      hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })
        hl.bind("left",   hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
        hl.bind("right",  hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
        hl.bind("up",     hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
        hl.bind("down",   hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })
        hl.bind("escape", hl.dsp.submap("reset"))
        hl.bind("return", hl.dsp.submap("reset"))
      end)
      hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

      -- Move focus (arrows + vim keys)
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))

      -- Focus / throw windows across the three monitors
      hl.bind(mainMod .. " + ALT + h", hl.dsp.focus({ monitor = "l" }))
      hl.bind(mainMod .. " + ALT + l", hl.dsp.focus({ monitor = "r" }))
      hl.bind(mainMod .. " + ALT + SHIFT + h", hl.dsp.window.move({ monitor = "l", follow = true }))
      hl.bind(mainMod .. " + ALT + SHIFT + l", hl.dsp.window.move({ monitor = "r", follow = true }))

      -- Switch / move-to workspaces on the current monitor (hyprsplit)
      for i = 1, 10 do
        local key = i % 10 -- 10 maps to key 0
        hl.bind(mainMod .. " + " .. key,         hs.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = true }))
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

      -- Media, volume, mic and brightness.
      -- There were NO such binds on deadPc, so Noctalia's OSD -- enabled with
      -- fifteen kinds -- had nothing to display. Routing through `noctalia msg`
      -- rather than wpctl/brightnessctl is what makes the OSD fire.
      -- `locked` keeps them working on the lock screen; `repeating` lets a held
      -- key ramp.
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"),   { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("noctalia msg volume-mute"), { locked = true })
      hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("noctalia msg mic-mute"),    { locked = true })

      hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("noctalia msg media toggle"),   { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("noctalia msg media toggle"),   { locked = true })
      hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("noctalia msg media next"),     { locked = true })
      hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("noctalia msg media previous"), { locked = true })
      hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("noctalia msg media stop"),     { locked = true })

      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("noctalia msg brightness-up"),   { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true })
    '';
  };
}
