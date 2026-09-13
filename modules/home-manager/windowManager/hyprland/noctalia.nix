{
  pkgs,
  config,
  inputs,
  vars,
  lib,
  starshipPromptTemplate,
  starshipRenderedConfig,
  ...
}: let
  videoWallpaper = "/home/${vars.username}/.config/wallpapers/video/anime-girl-near-car.mp4";

  mangleCacheName = lib.stringAsChars (c:
    if builtins.match "[A-Za-z0-9]" c != null
    then c
    else "_");
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.file.".config/wallpapers" = {
    source = ../../../../wallpapers;
    recursive = true;
  };

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

    systemd.enable = true;

    settings = {
      plugins = {
        auto_update = "none";
        enabled = [
          "kenn/keybind-cheatsheet"

          "dunarand/tmux-provider"

          "noctalia/mpvpaper"

          "jamesfeeder/special-workspaces"

          "cleboost/zed-provider"

          "nilsonlinux/rss-notifier"

          "felipeartur/ai-usagebar"
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
        avatar_path = "${../../assets/avatar.jpg}";

        launch_apps_as_systemd_services = true;

        polkit_agent = true;

        setup_wizard_enabled = false;

        font_family = "Adwaita Sans";

        screenshot = {
          directory = "/home/${vars.username}/Pictures/Screenshots";
          annotate = true;
          freeze_screen = true;
          copy_to_clipboard = true;
          save_to_file = true;
        };

        animation = {
          enabled = true;
          speed = 0.9;
        };

        launcher = {
          app_grid = false;
        };

        session = {
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

        screen_corners = {
          enabled = true;
          size = 32;
        };

        panel = {
          list_item_background = true;

          transparency_mode = "glass";

          launcher_placement = "floating";
          launcher_position = "center";
        };
      };

      theme = {
        source = "wallpaper";

        wallpaper_scheme = "vibrant";

        mode = "dark";

        templates = {
          enable_builtin_templates = true;

          builtin_ids = [
            "hyprland"
            "gtk3"
            "gtk4"
            "qt"
            "ghostty"
            "btop"
          ];

          enable_community_templates = true;
          community_ids = [
            "zed"
            "tmux"
            "fzf"
            "bat"

            "discord"
          ];

          user.starship = {
            input_path = "${starshipPromptTemplate}";
            output_path = starshipRenderedConfig;
          };
        };
      };

      hooks = {
        colors_changed = [
          "hyprctl eval '_G.noctalia_apply()'"

          "bat cache --build"
        ];

        session_locked = ["noctalia msg plugin noctalia/mpvpaper:service all pause"];
        session_unlocked = ["noctalia msg plugin noctalia/mpvpaper:service all resume"];
      };

      bar = {
        order = ["default"];
        default = {
          position = "top";
          margin_ends = 0;

          background_opacity = 0.4;

          capsule = true;
          capsule_fill = "surface_variant";
          capsule_opacity = 0.55;
          capsule_padding = 8;
          capsule_thickness = 0.78;

          padding = 12;
          widget_spacing = 8;

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
              members = ["cpu" "temp" "ram" "gpu" "gpu_temp" "network_rx" "network_tx"];
              padding = 8.0;
              opacity = 0.55;
            }
            {
              id = "media";
              members = ["audio_vis" "media"];
              padding = 8.0;
              opacity = 0.55;

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
              members = ["clock" "notifications" "rss" "ai_usage"];
              padding = 8.0;
              opacity = 0.55;
            }
          ];
        };
      };

      notification = {
        monitors = ["DP-3"];
        position = "top_right";
        background_opacity = 0.92;

        max_visible = 5;

        history_retention_hours = 168;
      };

      osd = {
        monitors = ["DP-3"];
        position = "bottom_center";
        background_opacity = 0.92;

        kinds = {
          media = false;
        };
      };

      widget."control-center" = {
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake-white.png";
        custom_image_colorize = true;
      };

      widget.rss = {
        type = "nilsonlinux/rss-notifier:badge";
      };

      widget.ai_usage = {
        type = "felipeartur/ai-usagebar:bar";
        vendor = "anthropic";
      };

      widget.gpu = {
        type = "sysmon";
        stat = "gpu_usage";
        glyph = "badge-3d";
      };

      widget.gpu_temp = {
        type = "sysmon";
        stat = "gpu_temp";
        glyph = "thermometer";
      };

      widget.audio_vis = {
        type = "audio_visualizer";
        width = 64;
        bands = 20;
        color_1 = "primary";
        color_2 = "secondary";
      };

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

      weather = {
        enabled = true;
        unit = "metric";
      };

      control_center = {
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

        calendar = {
          show_events_card = false;
          show_week_numbers = true;
        };
      };

      dock = {
        enabled = false;
      };

      lockscreen = {
        monitors = ["DP-3"];

        blur_intensity = 0.5;
        tint_intensity = 0.35;

        fingerprint = false;
      };

      lockscreen_widgets = {
        enabled = true;

        widget = {
          lock-backdrop = {
            type = "label";
            output = "DP-3";
            enabled = true;
            cx = 960.0;
            cy = 520.0;
            box_width = 640.0;
            box_height = 408.0;
            placement_width = 1920.0;
            placement_height = 1080.0;
            settings = {
              title = "";
              description = "";

              background = true;
              background_color = "surface";

              background_opacity = 0.55;

              background_radius = 32.0;
              shadow = false;
            };
          };

          lock-clock = {
            type = "clock";
            output = "DP-3";
            enabled = true;
            cx = 960.0;
            cy = 436.0;
            box_width = 560.0;
            box_height = 145.0;
            placement_width = 1920.0;
            placement_height = 1080.0;
            settings = {
              clock_style = "digital";
              format = "{:%H:%M}";
              center_text = true;
              background = false;
              color = "on_surface";

              shadow = true;
            };
          };

          lock-date = {
            type = "clock";
            output = "DP-3";
            enabled = true;
            cx = 960.0;
            cy = 527.0;
            box_width = 560.0;
            box_height = 24.0;
            placement_width = 1920.0;
            placement_height = 1080.0;
            settings = {
              clock_style = "digital";
              format = "{:%A, %d %B}";
              center_text = true;
              background = false;
              color = "on_surface_variant";
              shadow = true;
            };
          };

          "lockscreen-login-box@DP-3" = {
            type = "login_box";
            output = "DP-3";
            enabled = true;

            cx = 960.0;
            cy = 640.0;

            box_width = 560.0;

            box_height = 70.0;
            placement_width = 1920.0;
            placement_height = 1080.0;

            settings = {
              layout = "compact";

              background_opacity = 0.0;

              background_color = "surface";
              background_radius = 20.0;

              input_opacity = 1.0;
              input_radius = 12.0;
              center_password_text = true;

              show_login_button = true;

              show_caps_lock = true;

              show_unlock_hint = false;
              show_session_buttons = false;
              show_media = false;
              show_weather = false;

              show_keyboard_layout = false;
            };
          };

          "lockscreen-login-box@DP-2" = {
            type = "login_box";
            output = "DP-2";
            enabled = false;
            cx = 960.0;
            cy = 640.0;
            box_width = 560.0;
            box_height = 70.0;
            placement_width = 1920.0;
            placement_height = 1080.0;
            settings = {
              layout = "compact";
              show_media = false;
              show_weather = false;
              show_keyboard_layout = false;
            };
          };

          "lockscreen-login-box@HDMI-A-1" = {
            type = "login_box";
            output = "HDMI-A-1";
            enabled = false;
            cx = 960.0;
            cy = 640.0;
            box_width = 560.0;
            box_height = 70.0;
            placement_width = 1920.0;
            placement_height = 1080.0;
            settings = {
              layout = "compact";
              show_media = false;
              show_weather = false;
              show_keyboard_layout = false;
            };
          };
        };
      };

      idle = {
        pre_action_fade_seconds = 3.0;

        behavior = {
          lock = {
            action = "lock";
            enabled = true;
            timeout = 900.0;
          };
          screen-off = {
            action = "screen_off";
            enabled = true;
            timeout = 1200.0;
          };

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

        transition_on_startup = true;

        transition = ["fade"];

        automation.enabled = false;

        default.path = "/home/${vars.username}/.config/wallpapers/misty-boat.jpg";
      };
    };
  };

  home.activation.noctaliaMpvpaperAssignment = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="${config.xdg.stateHome}/noctalia/mpvpaper/assignments.json"
    if [ ! -e "$target" ]; then
      run install -Dm644 ${
      (pkgs.formats.json {}).generate "noctalia-mpvpaper-assignments.json" {
        assignments."*" = videoWallpaper;

        launchedAsSystemd = {};
      }
    } "$target"
    fi
  '';

  home.activation.noctaliaMpvpaperThumbnail = lib.hm.dag.entryAfter ["writeBoundary"] ''
    thumb="${config.xdg.cacheHome}/noctalia/mpvpaper/${mangleCacheName videoWallpaper}.jpg"
    if [ ! -e "$thumb" ]; then
      run install -Dm644 ${../../assets/mpvpaper-anime-girl-near-car.jpg} "$thumb"
    fi
  '';

  programs.noctalia.settings.plugin_settings = {
    "noctalia/mpvpaper" = {
      video_directory = "/home/${vars.username}/.config/wallpapers/video";
    };

    "nilsonlinux/rss-notifier" = {
      feed_urls = [
        "https://tldr.tech/api/rss/tech"
        "https://tldr.tech/api/rss/dev"
      ];
    };
  };
}
