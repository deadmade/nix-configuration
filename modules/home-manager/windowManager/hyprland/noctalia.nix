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

    # Derive Noctalia's palette from the global Stylix base16 scheme so the
    # shell tracks the system theme. (The stylix.targets.noctalia-shell target
    # is a no-op on noctalia v5 — it writes to programs.noctalia-shell.)
    customPalettes.stylix = {
      dark = with config.lib.stylix.colors.withHashtag; {
        mPrimary = base0D;
        mOnPrimary = base00;
        mSecondary = base0E;
        mOnSecondary = base00;
        mTertiary = base0C;
        mOnTertiary = base00;
        mError = base08;
        mOnError = base00;
        mSurface = base00;
        mOnSurface = base05;
        mSurfaceVariant = base01;
        mOnSurfaceVariant = base04;
        mOutline = base03;
        mShadow = base00;
        mHover = base0C;
        mOnHover = base00;
        terminal = {
          background = base00;
          foreground = base05;
          cursor = base05;
          cursorText = base00;
          selectionBg = base02;
          selectionFg = base05;
          normal = {
            black = base01;
            red = base08;
            green = base0B;
            yellow = base0A;
            blue = base0D;
            magenta = base0E;
            cyan = base0C;
            white = base05;
          };
          bright = {
            black = base03;
            red = base08;
            green = base0B;
            yellow = base0A;
            blue = base0D;
            magenta = base0E;
            cyan = base0C;
            white = base07;
          };
        };
      };
    };

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

        panel = {
          # v5 enum is attached | floating; "centered" was discarded with a
          # warning. floating + launcher_position = "center" is the real pair,
          # and is already the effective default -- this just makes it honest.
          launcher_placement = "floating";
          launcher_position = "center";
        };
      };

      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "stylix";
        templates = {
          enable_builtin_templates = true;
          builtin_ids = ["kitty"];
        };
      };

      # Bar layout. start/center/end take widget ids (or the predefined sysmon
      # widget instances cpu/temp/ram/network_rx/network_tx, and active_window).
      bar = {
        order = ["default"];
        default = {
          position = "top";
          margin_ends = 0; # span the full screen width (default 180 leaves end gaps)
          start = ["workspaces" "cpu" "temp" "ram" "network_rx" "network_tx"];
          center = ["active_window"];
          # control-center is the rightmost button; useDistroLogo makes it show
          # the detected OS logo (NixOS here) instead of the default noctalia icon.
          end = [
            "tray"
            "battery"
            "volume"
            "network"
            "session"
            "clock"
            "notifications"
            "control-center"
          ];
        };
      };

      # v5 moved per-widget options out of the lane lists into [widget.<id>].
      # `useDistroLogo` does not exist; a custom image plus colorize is how the
      # NixOS logo gets there, and colorize makes it track the wallpaper palette.
      widget."control-center" = {
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake-white.png";
        custom_image_colorize = true;
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
        automation = {
          enabled = true;
          interval_seconds = 300;
          order = "random";
        };
      };
    };
  };
}
