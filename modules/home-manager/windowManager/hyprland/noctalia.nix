{
  pkgs,
  config,
  inputs,
  vars,
  lib,
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

        # Was the literal string "sans-serif". Stylix's noctalia-shell target is a
        # v4 no-op (it writes programs.noctalia-shell.*, which does not exist in
        # the v5 module), so this has to be set explicitly.
        font_family = "Adwaita Sans";

        panel = {
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
        };
      };

      # hyprctl dispatch is NOT a Lua eval channel -- it wraps its argument in
      # `return hl.dispatch(...)`, so multi-statement Lua is a syntax error there.
      # `hyprctl eval` is the real one (verified live). This re-applies just the
      # palette rather than `hyprctl reload`, which would re-run the whole config
      # including hyprsplit's setup and every keybind registration.
      hooks = {
        colors_changed = [
          "hyprctl eval 'package.loaded[\"noctalia\"] = nil; local ok, m = pcall(function() return require(\"noctalia\") end); if ok and m.apply_theme then m.apply_theme() end'"
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

          start = ["workspaces" "group:sys"];
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

      control_center = {
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

      location = {
        address = "Augsburg";
      };

      weather = {
        enabled = false;
        unit = "metric";
      };

      wallpaper = {
        directory = "/home/${vars.username}/.config/wallpapers";
        fill_mode = "crop";
        # Fade the first wallpaper in at login instead of snapping to it.
        transition_on_startup = true;
        # A full desktop recolour every 5 minutes reads as a flicker you fight.
        # At 30 minutes it reads as an event, and the whole set still comes round
        # over a working day.
        automation = {
          enabled = true;
          interval_seconds = 1800;
          order = "random";
        };
      };
    };
  };
}
