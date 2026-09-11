{
  vars,
  pkgs,
  ...
}: {
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

          # A gutter between workspaces, so the slidefade transition reads as two
          # distinct surfaces passing rather than one continuous strip.
          gaps_workspaces = 24;
        };

        # SUPER+G groups windows, but the resulting groupbar was completely
        # unstyled -- stock flat tabs against a rounded, blurred, gradient-bordered
        # desktop. Match it to the window geometry so it looks like the same system.
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

            # Floating windows blur the WALLPAPER rather than the tiled windows
            # behind them -- much cleaner glass for the dialog/portal float rules.
            xray = true;
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

          # Inner glow: a rim light painted INWARD from the window edge, not an
          # outer halo. It traces rounding_power, so it follows the same squircle
          # as the border. Shipped disabled; entirely unused until now.
          #
          # This is what finally gives a focus cue on a three-monitor desktop.
          # dim_inactive (below) was rejected because only one window can ever be
          # focused, so it would permanently dim two thirds of the screens. A rim
          # light marks the hot window instead of darkening everything else.
          #
          # `color` is set dynamically from the palette in extraConfig.
          glow = {
            enabled = true;
            range = 8;
            # 1-4; higher = faster falloff, so the light hugs the edge instead of
            # washing into window content. 8px at power 4 is an edge, not a haze.
            render_power = 4;
            # Alpha dictates glow opacity, so a fully transparent inactive colour
            # means unfocused windows simply do not glow. That IS the cue.
            color_inactive = "rgba(00000000)";
          };

          # Windows smear along their travel vector while animating. This pairs
          # specifically with the under-critically-damped `snappy` spring: the
          # overshoot then reads as weight rather than as a wobble.
          #
          # NOTE: the shipped shader branches on USE_ROUNDING && !USE_MOTION_BLUR,
          # which implies corners are not rounded during a blurred frame. Verify
          # visually while dragging a window; drop this if corners visibly pop.
          motion_blur = {
            enabled = true;
            samples = 8;
          };

          # One static pass over the whole composited desktop: a gentle grade so
          # the wallpaper-derived palette reads a little richer. No plugin is
          # involved -- screen_shader is a built-in option that takes a path to a
          # fragment shader. The path must be absolute: the option resolves
          # relative to the main config, which is a /nix/store symlink.
          screen_shader = "${./shaders/grade.frag}";

          # dim_inactive is NOT enabled: on three monitors only one window can be
          # focused, so it would permanently dim two thirds of the desktop.
          # glow.color_inactive above is the focus cue instead.
          dim_inactive = false;

          # A different mechanism from dimming: lets the blur show THROUGH
          # unfocused windows rather than darkening them.
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

        # The session-start reveal. Hyprland's `monitorAdded` leaf drives a
        # 2x -> 1x zoom-out of the WHOLE monitor (src/output/Monitor.cpp:94 binds
        # m_zoomAnimProgress to it; onConnect:112 resets it; the present handler
        # fires it on the 5th scanout frame; Renderer.cpp:2133 maps it to
        # `2.0 - value`). onConnect runs for every monitor at compositor start,
        # so this has always fired -- but at ~1s it finished during the ~3.2s
        # gap before Noctalia paints anything, zooming out a blank screen.
        #
        # These control points hold the value near 0 (i.e. near 2x zoom) through
        # that dead gap, then ease out. The wallpaper and bar therefore appear
        # while the monitor is still zoomed, and settle into place.
        # NOTE: tuned against measured boot timing; expect to adjust after a
        # reboot-and-watch. See the plan's 6a section.
        {
          _args = [
            "reveal"
            {
              type = "bezier";
              points = [[0.85 0.0] [0.15 1.0]];
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
              # NOTE: the `speed` field on a spring-driven animation leaf is DEAD
              # CONFIG. hyprutils/src/animation/Spring.cpp computes duration only
              # from these three:
              #   OMEGA0 = sqrt(STIFFNESS / MASS);  GAMMA = DAMPING / (2 * MASS)
              # There is no speed/duration multiplier anywhere in the spring path.
              #
              # Duration scales as 1/sqrt(stiffness), so 330 -> 195 (i.e. / 1.69)
              # is 30% slower. Damping is rescaled with it to hold the damping
              # ratio zeta = c / (2*sqrt(m*k)) at 0.771 -- otherwise slowing it
              # down would also change how much it overshoots.
              mass = 1.0;
              stiffness = 195.0;
              dampening = 21.5;
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
              # Same 30% rescale, holding zeta at 1.001 (critically damped, no
              # overshoot). Rescaled alongside `snappy` rather than left alone
              # because this also drives workspaces/workspacesIn -- and since
              # speed is ignored on springs, workspace switching currently runs at
              # exactly the same rate as a window move. Slowing only one would
              # make workspace switches faster than window moves.
              mass = 1.0;
              stiffness = 124.0;
              dampening = 22.3;
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

        # The `speed` on these three spring-driven leaves is inert -- see the
        # note on the `snappy` curve above. To retime them, change the spring
        # constants, not these numbers.
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
          # Bezier-driven, so speed is real here (unlike the spring leaves above).
          # x1.3 to stay proportional to the slowed windowsIn.
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

        # 4s so the tail is still running when the desktop arrives. Also replays
        # on monitor hotplug, which is the same code path.
        {
          leaf = "monitorAdded";
          enabled = true;
          speed = 40.0;
          bezier = "reveal";
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
            decoration = {
              glow = {
                -- Static, deliberately: the border already rotates, and two
                -- co-rotating gradients read as a synchronised spinner.
                -- Offset 225deg from the border's 45 so the bright arcs sit
                -- opposite each other rather than stacking.
                color = { colors = { c.primary, c.secondary }, angle = 225 },
              },
            },
          })
        end

        -- Hyprland's stock misc:background_color is 0xFF111111, which is what
        -- fills the ~3.2s between login and Noctalia's first paint -- and, since
        -- wallpaper transition_on_startup fades up from ALPHA ZERO rather than
        -- from black, it is also the colour the wallpaper emerges out of.
        -- Noctalia's hyprland template never claims this key, so own it here and
        -- let it track the palette instead of sitting at a foreign grey.
        if c and c.surface then
          hl.config({ misc = { background_color = c.surface } })
        end
      end

      _G.noctalia_apply()

      -- NOT LOADED: hypr-dynamic-cursors.
      -- It is the one Hyprland plugin that looked worth having (shake-to-find
      -- magnification is genuinely useful on a 5760px desktop). It BUILDS
      -- correctly and links against this exact compositor -- `nix-store -q
      -- --references` on it lists the same hyprland-0.56.2 store path Hyprland
      -- runs from -- but it throws at init:
      --
      --   $ hyprctl plugin load .../libhypr-dynamic-cursors.so
      --   could not be loaded: plugin crashed/threw in main: std::exception
      --
      -- So a clean ABI match is NOT sufficient; the plugin's PLUGIN_INIT calls
      -- something 0.56.2 no longer provides. Its own author describes it as
      -- "more or less a joke" and does not guarantee updates. Left out.
      --
      -- For the record, the rest of the plugin ecosystem is worse: hyprexpo,
      -- hyprtrails and hyprwinwrap were DELETED upstream on 2026-05-12 ("all:
      -- drop unmaintained plugins (#663)"), and hyprspace -- the surviving
      -- expose -- 404s from the binary cache. There is no workspace overview
      -- available on 0.56.2 by any route.

      -- hyprsplit: awesome/dwm-like per-monitor workspaces (Lua library)
      local hs = require("hyprsplit")
      hs.config({ num_workspaces = 10 })

      -- Autostart.
      -- noctalia is started by its systemd user service (programs.noctalia.systemd.enable),
      -- bound to graphical-session.target, so it is not exec'd here.
      --
      -- librewolf used to launch straight from hyprland.start, which put a
      -- browser window on screen roughly 1.2s BEFORE the bar and wallpaper
      -- existed -- so the first thing seen after login was a bare browser on an
      -- empty field, with the desktop assembling behind it.
      --
      -- Wait for Noctalia's bar layer to map instead, then unsubscribe so a
      -- later bar restart (every `nhs` touches noctalia.service) does not spawn
      -- a second browser. hooks.started is NOT usable for this: Noctalia's hook
      -- commands are children of noctalia.service, so KillMode=control-group
      -- would take the browser down on every rebuild.
      local autostartSub
      autostartSub = hl.on("layer.opened", function(data)
        local ns = data and (data.namespace or data.nameSpace)
        if ns ~= "noctalia-bar-default" then return end
        if autostartSub then autostartSub:remove() end
        hl.exec_cmd(browser)
      end)

      -- Belt and braces: if the bar never maps (noctalia failed to start), still
      -- get a browser rather than an empty desktop.
      hl.timer(function()
        if autostartSub and autostartSub:is_active() then
          autostartSub:remove()
          hl.exec_cmd(browser)
        end
      end, { timeout = 15000, type = "oneshot" })

      -- Keybindings
      --
      -- Every bind carries a `description`. That is not decoration: with
      -- configType = "lua" Hyprland reports each bind to `hyprctl binds -j`
      -- with dispatcher "__lua" and an opaque numeric arg, so the description
      -- is the ONLY thing that can say what a key actually does. It is what
      -- SUPER+F1 (kenn/keybind-cheatsheet) renders.
      --
      -- The numbered `-- N. Title` section headings below are also load-bearing:
      -- the plugin re-scans this file and only recognises that exact form when
      -- grouping binds into categories. Plain `-- Title` is ignored. It keys
      -- categories off the description TEXT, so a given description string must
      -- stay unique to its section.
      --
      -- NOTE: Hyprland keysyms are case-insensitive and it fires EVERY matching
      -- bind. The previous map had `SUPER + L` (lock) alongside `SUPER + l`
      -- (focus right) and `SUPER + J` (togglesplit) alongside `SUPER + j`
      -- (focus down), so both of those keys ran two dispatchers at once.
      -- Anything sharing a letter with the hjkl block now lives elsewhere.

      -- 1. Applications
      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { description = "Open terminal" })
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser), { description = "Open browser" })
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "Open file manager" })
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus"), { description = "Open Nautilus" })
      hl.bind(mainMod .. " + C", hl.dsp.window.close(), { description = "Close window" })

      -- 2. Noctalia surfaces
      -- Every one of these was running but unbound.
      -- Panel ids are: clipboard, control-center, launcher, polkit, session,
      -- setup-wizard, test, tray-drawer, wallpaper. "notifications" is NOT a
      -- panel -- it is a control-center tab, which is why the old
      -- `panel-toggle notifications` bind did nothing at all.
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"), { description = "App launcher" })
      hl.bind(mainMod .. " + X",     hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo"), { description = "Emoji picker" })
      hl.bind(mainMod .. " + A",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"), { description = "Control center" })
      hl.bind(mainMod .. " + N",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"), { description = "Notifications" })
      hl.bind(mainMod .. " + B",     hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"), { description = "Clipboard history" })
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"), { description = "Wallpaper picker" })
      hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("noctalia msg settings-toggle"), { description = "Noctalia settings" })
      hl.bind("ALT + TAB",           hl.dsp.exec_cmd("noctalia msg window-switcher"), { description = "Window switcher" })
      -- Searchable cheatsheet of every bind, parsed from this very file.
      hl.bind(mainMod .. " + F1",    hl.dsp.exec_cmd("noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"), { description = "Keybind cheatsheet" })

      -- 3. Screenshots
      -- Noctalia's own stack, which also does annotation.
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"), { description = "Screenshot region" })
      hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"), { description = "Screenshot and annotate" })
      hl.bind("Print",                   hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"), { description = "Screenshot full screen" })
      hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick colour" })

      -- 4. Session
      -- Moved off L, which collided with focus-right.
      hl.bind(mainMod .. " + ESCAPE",         hl.dsp.exec_cmd("noctalia msg session lock || loginctl lock-session"), { description = "Lock session" })
      hl.bind(mainMod .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd("noctalia msg panel-toggle session"), { description = "Session menu" })
      hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Exit Hyprland" })

      -- 5. Window state
      -- togglesplit moved off J, which collided with focus-down.
      hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
      hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudotile" })
      hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })
      hl.bind(mainMod .. " + G", hl.dsp.group.toggle(), { description = "Toggle group" })
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen" })
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximise" })
      hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin(), { description = "Pin window" })

      -- 6. Mouse
      -- SUPER + drag to move/resize. This was simply not possible before.
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag to move window" })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Drag to resize window" })

      -- 7. Scratchpad
      hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })
      hl.bind(mainMod .. " + CTRL + S",  hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

      -- 8. Resize submap
      -- SUPER+R then hjkl/arrows, ESCAPE to leave.
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
      -- Arrows and vim keys are deliberately given the same labels: they are the
      -- same action, and the cheatsheet prints the key beside the label, so the
      -- pair of rows advertises that both work.
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
      hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
      hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
      hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
      hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })

      -- 10. Monitors
      -- Focus / throw windows across the three monitors.
      hl.bind(mainMod .. " + ALT + h", hl.dsp.focus({ monitor = "l" }), { description = "Focus monitor left" })
      hl.bind(mainMod .. " + ALT + l", hl.dsp.focus({ monitor = "r" }), { description = "Focus monitor right" })
      hl.bind(mainMod .. " + ALT + SHIFT + h", hl.dsp.window.move({ monitor = "l", follow = true }), { description = "Move window to left monitor" })
      hl.bind(mainMod .. " + ALT + SHIFT + l", hl.dsp.window.move({ monitor = "r", follow = true }), { description = "Move window to right monitor" })

      -- 11. Workspaces
      -- Switch / move-to workspaces on the current monitor (hyprsplit).
      -- The concatenated descriptions are intentional: the cheatsheet turns a
      -- concatenation into a PREFIX rule, which is what categorises all twenty.
      for i = 1, 10 do
        local key = i % 10 -- 10 maps to key 0
        hl.bind(mainMod .. " + " .. key,         hs.dsp.focus({ workspace = i }), { description = "Workspace " .. i })
        hl.bind(mainMod .. " + SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = true }), { description = "Move window to workspace " .. i })
      end

      -- 12. Move window
      -- Within the layout.
      hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
      hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
      hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })
      hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
      hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })
      hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
      hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })

      -- 13. Media and hardware keys
      -- There were NO such binds on deadPc, so Noctalia's OSD -- enabled with
      -- fifteen kinds -- had nothing to display. Routing through `noctalia msg`
      -- rather than wpctl/brightnessctl is what makes the OSD fire.
      -- `locked` keeps them working on the lock screen; `repeating` lets a held
      -- key ramp.
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
