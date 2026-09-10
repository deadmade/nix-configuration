{
  pkgs,
  config,
  inputs,
  vars,
  lib,
  starshipPromptTemplate,
  starshipRenderedConfig,
  ...
}: {
  # Import the noctalia home-manager module from flake
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.file.".config/wallpapers" = {
    source = ../../../../wallpapers;
    recursive = true;
  };

  # Noctalia plugins are sandboxed Luau scripts, not native code, so a `path`
  # source out of the /nix/store works with no build step -- the docs call this
  # kind "ideal for local development or Nix-managed plugins".
  #
  # Pinned to an exact rev so the plugin set is reproducible. This also lets
  # auto_update be turned off: it currently defaults to "all", which means a git
  # pull on startup and again every 6 hours -- the one genuinely non-reproducible
  # thing left in this config.
  #
  # Note the four chosen plugins are not decoration. Each one surfaces something
  # built in phases 1-5 that currently has no visible affordance at all.
  # Configure noctalia (v5 schema — see `noctalia config export full` for the
  # full set of keys/defaults; only deviations from the defaults are set here).
  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # Run noctalia as a systemd user service bound to graphical-session.target.
    # This makes home-manager auto-restart it when config.toml or the palette
    # changes (via the unit's X-Restart-Triggers).
    systemd.enable = true;

    settings = {
      plugins = {
        auto_update = "none";
        enabled = [
          # Searchable panel of every keybind. Parses the Lua config format --
          # it ships hyprland.lua test fixtures -- which matters because the
          # keymap was rewritten to 93 binds in phase 5.
          "kenn/keybind-cheatsheet"
          # `/tm` in the launcher lists and attaches tmux sessions. The terminal
          # already autostarts `tmux new-session -A -s main`.
          "dunarand/tmux-provider"
          # Animated wallpapers (wallpapers/video/). It supervises one mpvpaper
          # per output AND tells Noctalia to drop its own wallpaper on just the
          # outputs a video is assigned to, which is the whole reason to use the
          # plugin instead of running mpvpaper directly -- a bare mpvpaper would
          # draw a second layer-shell surface fighting the one configured under
          # `wallpaper` below. mpvpaper/mpv/socat are in default.nix and are
          # required, not optional: without mpv there are no thumbnails.
          "noctalia/mpvpaper"
          # NOT enabled: k4n4t4/hypr-submap. It loads, but every poll throws
          #   submap.luau:39: invalid argument #1 to 'trim' (string expected,
          #   got table)
          # because it calls noctalia.runAsync("hyprctl submap", cb) expecting a
          # plain string, while this runtime hands the callback a table. It
          # declares plugin_api = 6 against a shell at 25 -- the declared value
          # is only a MINIMUM, so it does not protect against a changed callback
          # signature. Nothing to fix on our side.
          # Indicator for populated scratchpads. SUPER+S got a scratchpad in
          # phase 5 with no way to tell whether anything was in it.
          "jamesfeeder/special-workspaces"
        ];

        source = [
          {
            name = "community-pinned";
            kind = "path";
            location = "${pkgs.fetchFromGitHub {
              owner = "noctalia-dev";
              repo = "community-plugins";
              rev = "ea86850b8c21f9f8f3663021163b8f071040986d";
              hash = "sha256-7I7A4EuxiRTRZycDOErPP8oSdtAcv7zhJEpQU+S2mq0=";
            }}";
            enabled = true;
          }
          # Same treatment for the official set, which ships noctalia/mpvpaper.
          # Pinned as a path source rather than re-enabling the built-in
          # `official` git source below, so nothing is fetched at startup.
          {
            name = "official-pinned";
            kind = "path";
            location = "${pkgs.fetchFromGitHub {
              owner = "noctalia-dev";
              repo = "official-plugins";
              rev = "f5d7f8049da8b7e830b6d3d57761bb869e46cede";
              hash = "sha256-mYUomM1N+7eD65g6Mdfntn5rMrUBcH6T1BZuDBj3OmI=";
            }}";
            enabled = true;
          }
          # The two built-in git sources are protected from removal but can be
          # switched off by name. Without this they keep pulling over the network.
          {
            name = "community";
            enabled = false;
          }
          {
            name = "official";
            enabled = false;
          }
        ];
      };

      shell = {
        # ~/.face never existed. Point at the avatar committed in this repo so the
        # lock screen and control-center user card actually render one.
        avatar_path = "${../../assets/avatar.jpg}";

        # Apps launched from the launcher become children of noctalia.service
        # otherwise, so every `nhs` that restarts the unit kills them.
        launch_apps_as_systemd_services = true;

        # security.polkit.enable is on but no agent was running, so GUI privilege
        # prompts failed silently. Noctalia ships one and it follows the theme.
        polkit_agent = true;

        # Only suppressed today by a marker file in ~/.local/state, which is not
        # declarative -- any state wipe or new machine and a first-run wizard
        # panel appears over the opening.
        setup_wizard_enabled = false;

        # Was the literal string "sans-serif". Stylix's noctalia-shell target is a
        # v4 no-op (it writes programs.noctalia-shell.*, which does not exist in
        # the v5 module), so this has to be set explicitly.
        font_family = "Adwaita Sans";

        # Noctalia's screenshot subsystem replaces hyprshot. Without a directory
        # it saves next to wherever it was launched from.
        screenshot = {
          directory = "/home/${vars.username}/Pictures/Screenshots";
          annotate = true;
          freeze_screen = true;
          copy_to_clipboard = true;
          save_to_file = true;
        };

        # Slightly under 1.0 so panels and OSDs feel weighted rather than
        # snapping. Global multiplier over every shell transition.
        animation = {
          enabled = true;
          speed = 0.9;
        };

        launcher = {
          # List, not the icon grid. (false is the default; stated explicitly
          # because phase 6 had set it true.)
          app_grid = false;
        };

        session = {
          # grid is deliberately NOT set. With it false (the default) and five
          # actions, session_panel.cpp:109-125 fits them on ONE row -- ~810x112
          # rather than the ~490x250 3+2 block, whose second row is half empty
          # because the grid uses uniform cell sizes.
          #
          # Note placement/position do NOT affect the panel's size: it is
          # computed purely from the button grid, so there is no separate
          # "bigger dialog" knob.
          actions = [
            {
              action = "lock";
              shortcut = "1";
              enabled = true;
            }
            {
              action = "logout";
              shortcut = "2";
              enabled = true;
            }
            {
              action = "lock_and_suspend";
              shortcut = "3";
              enabled = true;
            }
            {
              action = "reboot";
              shortcut = "4";
              enabled = true;
              variant = "destructive";
              countdown_seconds = 5.0;
            }
            {
              action = "shutdown";
              shortcut = "5";
              enabled = true;
              variant = "destructive";
              countdown_seconds = 5.0;
            }
          ];
        };

        panel = {
          # Filled rounded backgrounds behind launcher and clipboard rows -- a
          # card treatment that plays into the glass panels.
          list_item_background = true;

          # "solid" ignores the palette's translucency entirely; "glass" lets the
          # blurred desktop through the launcher/control-centre/session panels.
          transparency_mode = "glass";

          # v5 enum is attached | floating; "centered" was discarded with a
          # warning. floating + launcher_position = "center" is the real pair,
          # and is already the effective default -- this just makes it honest.
          launcher_placement = "floating";
          launcher_position = "center";
        };
      };

      theme = {
        # Material You: the whole palette is regenerated from whatever wallpaper
        # is currently up, and every enabled template is re-rendered with it.
        source = "wallpaper";

        # Picked by generating real palettes from this wallpaper set and
        # comparing them, not by reasoning about the generator names.
        #
        #   scheme          Clearnight.jpg        dark-waves.jpg
        #   m3-content      primary #bec2ff       primary #bec6e0
        #   m3-tonal-spot   primary #bec2ff       primary #b0c6ff
        #   vibrant         primary #65a8e7       primary #6781e4
        #
        # This set is overwhelmingly dark and low-chroma (16 of 27 images
        # quantise to the same blue-grey ramp). Material's tonal machinery pushes
        # such seeds into a high-tone pastel band, so BOTH m3 generators produce a
        # near-white accent that barely changes between wallpapers -- which
        # defeats the point of driving colour from the wallpaper at all.
        #
        # vibrant keeps chroma, gives three genuinely distinct accents for the bar
        # capsules (primary #65a8e7 / secondary #4f50e3 / tertiary #974fe3), and
        # still emits all 72 roles including the full surface_container_* ramp --
        # tinted toward the wallpaper rather than neutral grey.
        wallpaper_scheme = "vibrant";

        # Not "auto": mode selects the variant every template WRITES, so auto
        # would rewrite ghostty/btop/gtk/qt/hyprland config files twice a day.
        mode = "dark";

        templates = {
          enable_builtin_templates = true;

          # Every builtin template applies itself by rewriting the target app's
          # own config file, and Home Manager owns those as read-only store
          # symlinks. Each id here is one that has been made safe:
          #   hyprland    -- config.nix carries the literal require("noctalia")
          #                  its apply.sh greps for, so the append no-ops
          #   gtk3/gtk4   -- stylix.targets.gtk is off and gtk4.theme = null, so
          #                  HM no longer writes gtk.css at all
          #   qt          -- writes only a palette file; desktop/qt.nix points
          #                  qt5ct/qt6ct at it
          #   ghostty/btop -- theme name pre-seeded so apply.sh no-ops
          # kitty is gone: it was the ONLY id enabled, for a terminal that is
          # disabled. bat/fzf/fastfetch/obs are deliberately absent -- they write
          # files nothing reads, and bat additionally breaks its own cache.
          builtin_ids = [
            "hyprland"
            "gtk3"
            "gtk4"
            "qt"
            "ghostty"
            "btop"
          ];

          # Community templates. NOTE the first apply of any new id needs
          # NETWORK: the cached dirs hold only template.toml, and payloads are
          # fetched from api.noctalia.dev. A failing id is contained -- the
          # apply service warns per id and carries on.
          #
          # Only ids that something actually READS are here. Deliberately absent:
          #   neovim    -- writes ~/.config/nvim/lua/matugen.lua, but nvim comes
          #                from an opaque external flake and never puts that path
          #                on runtimepath. Unfixable from this repo.
          #   vscode    -- writes into a version-pinned marketplace extension dir
          #                (noctaliatheme-0.0.5) that is not installed.
          #   fastfetch -- EACCES on the HM-owned config.jsonc, AND fastfetch has
          #                no include directive, so the theme file is unreadable
          #                by any config line.
          enable_community_templates = true;
          community_ids = [
            "zed"
            "tmux"
            "fzf"
            "bat"
            # Lands safely but Vencord only injects themes named in
            # enabledThemes, which nixcord never writes (it is disabled). Tick
            # "noctalia" once in Vesktop -> Settings -> Themes; it persists and
            # re-renders on every palette change.
            "discord"
          ];

          # The builtin `starship` id is deliberately NOT in the list above: its
          # apply.sh does `cat "$tmp" > "$STARSHIP_CONFIG"`, and home-manager
          # points that at a read-only /nix/store symlink -> EACCES, killing the
          # hook. A user template sidesteps apply.sh entirely by rendering to a
          # path we choose.
          #
          # The prompt LAYOUT stays in this repo (terminal/starship/starship.toml);
          # only the palette block is substituted, so the prompt is generated from
          # the same wallpaper as the terminal it sits in.
          user.starship = {
            input_path = "${starshipPromptTemplate}";
            output_path = starshipRenderedConfig;
          };
        };
      };

      # hyprctl dispatch is NOT a Lua eval channel -- it wraps its argument in
      # `return hl.dispatch(...)`, so multi-statement Lua is a syntax error there.
      # `hyprctl eval` is the real one (verified live). This re-applies just the
      # palette rather than `hyprctl reload`, which would re-run the whole config
      # including hyprsplit's setup and every keybind registration.
      hooks = {
        # _G.noctalia_apply is defined in config.nix's extraConfig. It busts the
        # module cache, re-applies the palette AND rebuilds the gradient border.
        colors_changed = [
          "hyprctl eval '_G.noctalia_apply()'"
          # bat only sees a .tmTheme after its cache is rebuilt, and the bat
          # template's own apply.sh never gets that far (it dies EACCES on the
          # HM-owned bat/config first). This fires after templates render.
          "bat cache --build"
        ];
      };

      # Bar layout. Lanes take widget instance ids; per-widget options live in
      # [widget.<id>] and shared-pill grouping in [[bar.default.capsule_group]].
      bar = {
        order = ["default"];
        default = {
          position = "top";
          margin_ends = 0; # span the full screen width (default 180 leaves end gaps)

          # PRECONDITION for the compositor blur in the Hyprland layer rules: the
          # bar was fully opaque, so any amount of blur behind it was invisible.
          # 0.40 sits well above the layer rule's ignore_alpha threshold (0.25),
          # which is what decides whether Hyprland bothers blurring the surface.
          background_opacity = 0.4;

          # Widgets sit in pills rather than floating loose on the rail. Related
          # ones share a single pill via capsule_group below.
          capsule = true;
          capsule_fill = "surface_variant";
          capsule_opacity = 0.55;
          capsule_padding = 8;
          capsule_thickness = 0.78;

          padding = 12;
          widget_spacing = 8;

          # Both plugin widgets are conditional -- Noctalia hides a capsule
          # automatically when its widget reports no visible ink -- so they cost
          # nothing when there is no scratchpad and no active submap.
          start = ["workspaces" "scratchpads" "group:sys"];
          center = ["active_window"];
          end = [
            "group:media"
            "tray"
            "group:status"
            "group:time"
            "session"
            "control-center"
          ];

          capsule_group = [
            {
              id = "sys";
              members = ["cpu" "temp" "ram" "network_rx" "network_tx"];
              padding = 8.0;
              opacity = 0.55;
            }
            {
              id = "media";
              members = ["audio_vis" "media"];
              padding = 8.0;
              opacity = 0.55;
              # Collapse to just the spectrum until hovered, so a long track
              # title does not shove the centred window title off-centre.
              accordion = true;
              accordion_direction = "end";
            }
            {
              id = "status";
              members = ["privacy" "caffeine" "nightlight" "network" "volume"];
              padding = 8.0;
              opacity = 0.55;
            }
            {
              id = "time";
              members = ["clock" "notifications"];
              padding = 8.0;
              opacity = 0.55;
            }
          ];
        };
      };

      # Notifications and the OSD default to monitors = [], which puts them on
      # every output. On three screens that means the same toast three times.
      # DP-3 is the centre 240Hz panel and the one actually being looked at.
      notification = {
        monitors = ["DP-3"];
        position = "top_right";
        background_opacity = 0.92;
        # 0 means unlimited, which lets a burst of notifications cover the screen.
        max_visible = 5;
        # 0 means keep forever; the history file was already 52 KB.
        history_retention_hours = 168;
      };

      osd = {
        monitors = ["DP-3"];
        position = "bottom_center";
        background_opacity = 0.92;
      };

      # v5 moved per-widget options out of the lane lists into [widget.<id>].
      # `useDistroLogo` does not exist; a custom image plus colorize is how the
      # NixOS logo gets there, and colorize makes it track the wallpaper palette.
      widget."control-center" = {
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake-white.png";
        custom_image_colorize = true;
      };

      # Reads the PipeWire monitor stream directly -- no cava needed. The two
      # gradient roles track the wallpaper palette, so the spectrum recolours
      # along with everything else.
      widget.audio_vis = {
        type = "audio_visualizer";
        width = 64;
        bands = 20;
        color_1 = "primary";
        color_2 = "secondary";
      };

      # Plugin widgets take type = "<author>/<plugin>:<entry>".
      widget.scratchpads = {
        type = "jamesfeeder/special-workspaces:special-workspaces";
      };

      widget.media = {
        type = "media";
        max_length = 200.0;
        title_scroll = "on_hover";
      };

      widget.active_window = {
        type = "active_window";
        max_length = 320.0;
        title_scroll = "on_hover";
      };

      # location.address is already set and weather.effects already defaults to
      # true, so enabling weather unlocks an animated, palette-tinted GLSL effect
      # (Rain/Snow/Cloud/Fog/Sun/Stars, chosen by WMO code) inside the Control
      # Center's conditions card -- and makes the lock screen's already-enabled
      # weather row render something instead of nothing.
      weather = {
        enabled = true;
        unit = "metric";
      };

      control_center = {
        # "full" shows icons AND labels in the sidebar; the extra width stops the
        # weather card and its effect from being cramped.
        sidebar = "full";
        width = 900;

        shortcuts = [
          {type = "wifi";}
          {type = "bluetooth";}
          {type = "wallpaper";}
          {type = "notification";}
          {type = "power_profile";}
          {type = "caffeine";}
          {type = "nightlight";}
        ];

        # v5 has no [[calendar.cards]]. Top-level [calendar] is the CalDAV sync
        # service; the clock-popup calendar is configured here instead.
        calendar = {
          show_events_card = false;
          show_week_numbers = true;
        };
      };

      # The dock (running-apps menu) is disabled.
      dock = {
        enabled = false;
      };

      lockscreen = {
        # NOT which screens lock -- ext-session-lock locks all of them by
        # protocol. This is which are INTERACTIVE (lock_screen.cpp:633-655 ->
        # setBlackout(!interactive)). The centre 240Hz panel gets wallpaper,
        # blur and the login box; the two sides go solid black. One composed
        # screen instead of three copies of the same widget.
        #
        # It also collapses the config: only DP-3's login-box entry is ever
        # consulted, so one widget table is needed instead of three.
        #
        # Safety valve at :648-651 -- if no configured selector matches a present
        # output, the restriction is dropped rather than blacking out everything.
        monitors = ["DP-3"];

        # Defaults are 0.5/0.3. This wallpaper is low-contrast and misty, so the
        # login box needs the background pushed further back to read as
        # foreground, and the tint is what buys legible text on top of it.
        blur_intensity = 0.7;
        tint_intensity = 0.5;

        # Inert on this host -- the shell logs "no fprintd device available" on
        # every start. Off, so it stops trying.
        fingerprint = false;
      };

      # The login box renders even though lockscreen_widgets.enabled stays false:
      # LockSurface reads this config directly via findForOutput
      # (lock_surface.cpp:1573-1595) and never consults the widgets gate. Leaving
      # `enabled` unset keeps the widget host/editor overlay off while still
      # styling the box.
      #
      # NOTE: `widget_order` is deliberately absent. When present it acts as an
      # allowlist and silently drops any id not named in it.
      lockscreen_widgets = {
        widget."lockscreen-login-box@DP-3" = {
          type = "login_box";
          output = "DP-3";
          enabled = true;
          box_width = 760.0;

          settings = {
            layout = "regular";

            # A palette role, so it tracks the wallpaper. `surface` is a step
            # darker than the default surface_variant and reads as a panel
            # rather than a chip. Note the surface_container* roles exist in the
            # palette but are NOT accepted here -- the config token set is
            # narrower than the role set, and the build-time validator rejects
            # them (verified against `noctalia config validate`).
            background_color = "surface";
            background_opacity = 0.72;
            background_radius = 20.0;
            input_opacity = 1.0;
            input_radius = 12.0;
            center_password_text = true;

            show_session_buttons = true;
            show_login_button = true;
            show_unlock_hint = true;
            show_caps_lock = true;
            show_media = true;
            # Has real data now that weather is enabled; renders once the first
            # fetch lands after a cold start.
            show_weather = true;
            # Single layout on this machine, so the row is permanent noise.
            show_keyboard_layout = false;
          };
        };
      };

      # The machine never locked, never blanked and never suspended: all three
      # Noctalia idle behaviours default to enabled = false and nothing set them.
      # This is the desktop ladder; deadConvertible overrides it with mkForce.
      #
      # behavior_order is deliberately NOT set here. It is a list, and lists
      # merge by CONCATENATION with no error, so defining it in both a module
      # and a host would silently produce a nonsense order.
      idle = {
        pre_action_fade_seconds = 3.0;
        # `action` MUST be set explicitly. Declaring an [idle.behavior.<name>]
        # table replaces the built-in entry rather than merging into it, so
        # enabled+timeout alone gets you `idle behavior 'lock' ignored: needs an
        # action` at runtime -- and `noctalia config validate` does NOT catch it.
        behavior = {
          lock = {
            action = "lock";
            enabled = true;
            timeout = 900.0; # 15 min
          };
          screen-off = {
            action = "screen_off";
            enabled = true;
            timeout = 1200.0; # 20 min
          };
          # A desktop that suspends is a desktop that drops SSH sessions and
          # long builds. deadConvertible turns this on.
          lock-and-suspend = {
            action = "lock_and_suspend";
            enabled = false;
          };
        };
      };

      location = {
        address = "Augsburg";
      };

      wallpaper = {
        directory = "/home/${vars.username}/.config/wallpapers";
        fill_mode = "crop";
        # Fade the first wallpaper in at login instead of snapping to it.
        transition_on_startup = true;

        # The startup transition type is picked UNIFORMLY AT RANDOM from this
        # pool -- there is no startup-specific key -- so leaving all six in meant
        # the login reveal was a coin flip that could land on honeycomb or
        # stripes. Those are built to blend two IMAGES and read as artifacts
        # against a solid colour, which is what transition_on_startup fades from.
        #
        # fade is also the right partner for the monitor zoom-out in config.nix:
        # the wallpaper fades UP while the monitor zooms OUT. Noctalia's own
        # `zoom` transition would compound into a double zoom.
        transition = ["fade"];
        # Rotation off. Nothing is removed: all 27 images stay in wallpapers/ and
        # stay deployed to ~/.config/wallpapers, and `directory` above remains the
        # browse root, so the wallpaper picker and the /wall launcher provider
        # still work. Only the timer stops.
        automation.enabled = false;

        # REQUIRED, not optional. Wallpaper::applyStartupAutomation
        # (wallpaper.cpp:904-908) returns early when automation is off, and that
        # early return is the only thing that would otherwise scan `directory` at
        # startup -- so without an explicit path there would be no wallpaper at
        # all.
        #
        # This is a DEFAULT, not a lock: picking another wallpaper from the panel
        # or /wall writes to ~/.local/state/noctalia/settings.toml, which loads
        # last and wins. That is the intended manual override.
        default.path = "/home/${vars.username}/.config/wallpapers/misty-boat.jpg";
      };
    };
  };

  # The mpvpaper picker's per-output assignments are RUNTIME STATE, not a config
  # setting -- the plugin's manifest declares no key for them. The service reads
  # this file at startup and REWRITES it on every change (mpvpaper_service.luau
  # persist/loadAssignments, STATE_FILE), so a home.file store symlink is not an
  # option: the plugin's writeFile would die with EACCES the first time a video
  # is picked, the same failure core/stylix.nix documents for Noctalia's apply.sh
  # scripts. Seeding a real writable file is the only way to get a video
  # wallpaper on a fresh install without opening the picker by hand.
  #
  # "*" means every output, resolved at runtime against noctalia.outputs(), so
  # this is correct for deadPc's three monitors and deadConvertible's one alike.
  #
  # Seeded only when ABSENT, which makes it a DEFAULT and not a lock -- the same
  # posture as wallpaper.default.path above. Picking a different video in the
  # picker rewrites the file and that choice then survives every later rebuild.
  # To force the repo's choice back, delete the file and re-run `nhs`.
  home.activation.noctaliaMpvpaperAssignment = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="${config.xdg.stateHome}/noctalia/mpvpaper/assignments.json"
    if [ ! -e "$target" ]; then
      run install -Dm644 ${
      (pkgs.formats.json {}).generate "noctalia-mpvpaper-assignments.json" {
        assignments."*" = "/home/${vars.username}/.config/wallpapers/video/kaneki-abyss.mp4";
        # The plugin tracks which outputs it wrapped in a systemd scope here.
        # run_as_systemd is off, so it starts empty rather than absent -- the
        # loader reads decoded.launchedAsSystemd and expects a table.
        launchedAsSystemd = {};
      }
    } "$target"
    fi
  '';

  # Plugin settings are a TOML table of their own -- top-level
  # [plugin_settings."author/plugin"], NOT nested under [plugins] -- keyed by the
  # `key` fields in each plugin's plugin.toml. Only deviations from the manifest
  # defaults are set, same rule as the rest of this file.
  programs.noctalia.settings.plugin_settings = {
    # Points the picker at the video half of the wallpaper set. Everything else
    # the plugin defaults to is already right: mute = true (the loops have no
    # audio track anyway), hardware_decode = true, auto_pause = "full" (pauses
    # behind fullscreen windows), extract_last_frame = true (leaves a still
    # behind when playback stops, which is what keeps a wallpaper on screen and
    # is presumably what the palette generator reads).
    "noctalia/mpvpaper" = {
      video_directory = "/home/${vars.username}/.config/wallpapers/video";
    };
  };
}
