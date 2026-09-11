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
  # The video wallpaper, named once. Three things derive from this path: the
  # per-output assignment seeded below, the picker thumbnail's cache filename,
  # and (via that thumbnail) the palette every other app is themed from.
  videoWallpaper = "/home/${vars.username}/.config/wallpapers/video/anime-girl-near-car.mp4";

  # mpvpaper_service.luau:251-253 -- cachePath() is `path:gsub("[^%w]", "_")`
  # with a .jpg suffix, i.e. every non-alphanumeric byte becomes an underscore.
  # Lua's %w is ASCII alphanumeric here.
  mangleCacheName = lib.stringAsChars (c:
    if builtins.match "[A-Za-z0-9]" c != null
    then c
    else "_");
in {
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
          # Animated wallpapers (wallpapers/video/). It supervises mpvpaper AND
          # tells Noctalia to drop its own wallpaper on just the outputs a video
          # is assigned to, which is the whole reason to use the plugin instead
          # of running mpvpaper directly -- a bare mpvpaper would draw a second
          # layer-shell surface fighting the one configured under `wallpaper`
          # below. mpvpaper/mpv/socat are in default.nix and are required, not
          # optional: without mpv there are no thumbnails.
          #
          # The plugin.toml header says "one mpvpaper instance per output"; that
          # is only true of per-connector assignments. This host assigns the
          # wildcard "*", which mpvpaper itself expands, so it is ONE process
          # painting all three monitors (~528MB RSS, ~5% of a core).
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

          # The four above expose things this repo BUILT; this one exposes the
          # toolchain it USES. `/zed` in the launcher lists recent Zed projects,
          # read straight out of Zed's own sqlite store -- so there is no list to
          # maintain here. Needs the sqlite3 CLI; see default.nix.
          #
          # It adds no bar widget -- it is a launcher provider only, which is why
          # nothing in the bar layout below refers to it.
          #
          # Five others were enabled alongside it and then removed as not wanted:
          # the same idea for nvim and the JetBrains IDEs, a colour picker, a
          # nixpkgs update monitor, and a GitHub PR status pill.
          "cleboost/zed-provider"

          # Dev news in the bar. A generic RSS/Atom reader -- there is no
          # TLDR-specific plugin and none is needed, because tldr.tech publishes
          # real RSS at /api/rss/<edition> (verified: 200 + <rss>, 20 items,
          # newest same-day). Feeds are set in plugin_settings at the bottom.
          #
          # Three entries: a `fetcher` service that polls and parses, the `badge`
          # bar widget placed below, and a `Panel` listing the items --
          # note the CAPITAL P in the panel id, which the IPC command needs:
          #   noctalia msg panel-toggle nilsonlinux/rss-notifier:Panel
          # (its README says the widget is called `indicator`; the manifest says
          # `badge`, and the manifest is what the shell reads.)
          #
          # Only hard dependency is xdg-open, already in /run/current-system/sw.
          "nilsonlinux/rss-notifier"

          # NOT enabled: cleboost/ssh-launcher. It parses ~/.ssh/config, and
          # that file does not exist on this host -- the provider would return
          # an empty list forever. deadServer and deadPi are reached through
          # deploy-rs (flake/modules/deploy.nix), not through an ssh config.
          # Worth adding once an ~/.ssh/config exists.

          # NOT enabled: jrohland/claudecode. It loads and its collector script
          # is correct -- run by hand it exits 0 with real data -- but it can
          # never report on THIS account, because the data collection is three
          # times slower than the runtime will wait:
          #
          #   $ time bash .../claudecode/get-claude-usage --json
          #   ~14.9 s  (twice, with pricing-cache.json and usage-cache.json
          #             already warm, so this is not first-run cost)
          #
          # noctalia.runAsync's third argument is a timeout that DEFAULTS to
          # 5000 ms (luau_host.cpp:59, clamped to [50, 60000]), and
          # service.luau:44 calls it with two arguments -- so the fetch is
          # killed at 5 s, every time, exactly:
          #
          #   19:35:48.080 started service 'jrohland/claudecode:service'
          #   19:35:53.104 claudecode: get-claude-usage failed   (+5.024 s)
          #   19:37:53.114 claudecode: get-claude-usage failed
          #   19:39:53.114 claudecode: get-claude-usage failed
          #
          # The 15 s is this account's own history -- the script walks every
          # session transcript under ~/.claude to total tokens, and there are
          # 160 sessions / 16.7k messages of it. So it gets WORSE over time, and
          # refresh_interval cannot help: the limit is per invocation, not per
          # hour.
          #
          # Left out rather than worked around. The fix belongs upstream (pass a
          # timeout to runAsync), and the alternative here -- vendoring a patched
          # copy of the plugin out of the pinned path source -- is a lot of
          # machinery to carry for one bar pill.
          #
          # Worth knowing if it is ever revisited: script_runtime.cpp:46 auto
          # disables a plugin after kMaxConsecutiveTimeouts = 3, so leaving it on
          # does not even fail quietly.
          #
          # For the record, since this is the one plugin in the set that reads a
          # credential: it pulls .claudeAiOauth.accessToken out of
          # ~/.claude/.credentials.json and calls api.anthropic.com with it
          # (get-claude-usage:246-272).
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

        # Overlays rounded black corners on every screen, so the desktop itself
        # has the same corner treatment as the windows on it. 32 is the top of
        # the 1..100 range the schema clamps to, and is deliberately larger than
        # the 12px window rounding: a screen corner sits further from the eye
        # than a window corner, so an equal radius reads as sharper.
        #
        # This is drawn per output, so it also softens the two OUTER corners of
        # each side monitor. The inner ones butt against the neighbouring panel,
        # where the rounding reads as a small notch in the seam rather than as a
        # corner -- verify by eye before keeping.
        screen_corners = {
          enabled = true;
          size = 32;
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

        # The mpvpaper plugin has NO lock, DPMS, idle or power handling of its
        # own -- grepped across every file in it. Left alone it keeps decoding
        # 1080p behind the lock screen at ~5% of a core for as long as the
        # session is locked. These are the only hooks that can reach it.
        #
        # `plugin <author/plugin:entry> <target> <event> [payload]`
        # (plugin_ipc.cpp:15, :44-52). `service` is a singleton entry bound to no
        # output, so the target MUST be `all` -- an output selector never names
        # it (:113-121). The payload is deliberately EMPTY: mpvpaper_service.luau
        # :643-657 freezes every assignment when the payload is not a non-empty
        # string, which is what we want, whereas a literal "all" would be read as
        # a connector name and match nothing.
        #
        # With run_as_systemd = false this is pkill -STOP / -CONT, so the CPU
        # stops but the ~500MB of decoder buffers stay resident. SIGSTOP also
        # freezes the last frame on screen, which is what the lock screen blurs.
        session_locked = ["noctalia msg plugin noctalia/mpvpaper:service all pause"];
        session_unlocked = ["noctalia msg plugin noctalia/mpvpaper:service all resume"];
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
              members = ["cpu" "temp" "ram" "gpu" "gpu_temp" "network_rx" "network_tx"];
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
              members = ["clock" "notifications" "rss"];
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

        # All ~15 OSD kinds are on by default. `media` is the one that is pure
        # duplication here: it fires on MPRIS play/pause, on every track change
        # AND on per-player volume changes, while the bar already carries a
        # permanent media capsule (group:media, with the spectrum) on the same
        # monitor the OSD is pinned to. So a track change drew the same
        # information twice, once transiently over the bottom of the screen.
        #
        # Everything else stays on deliberately -- volume, brightness and the
        # lock keys have NO permanent bar presence, so for those the OSD is the
        # only feedback there is.
        kinds = {
          media = false;
        };
      };

      # v5 moved per-widget options out of the lane lists into [widget.<id>].
      # `useDistroLogo` does not exist; a custom image plus colorize is how the
      # NixOS logo gets there, and colorize makes it track the wallpaper palette.
      widget."control-center" = {
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake-white.png";
        custom_image_colorize = true;
      };

      # GPU. There is no seeded `gpu` instance the way there is for cpu/temp/ram
      # and the two network stats (config/widget_config.cpp:56-110 seeds ten
      # instances and none of them is a GPU), so these two tables are what make
      # the ids in the `sys` capsule resolve at all.
      #
      # Noctalia loads NVML directly and does NOT shell out to nvidia-smi
      # (docs services/system-monitor.mdx:87). libnvidia-ml.so.1 is present via
      # /run/opengl-driver/lib -> nvidia-x11-595.99.02, so this works on the
      # proprietary driver this host already runs. It would NOT work on nouveau,
      # which ships no NVML.
      #
      # Placed after `ram` and before the network pair so the capsule reads
      # CPU -> memory -> GPU -> network rather than interleaving them.
      #
      # gpu_vram was considered instead of gpu_temp: on a 3070 the 8GB VRAM
      # ceiling is the more common wall. Kept temp because the capsule already
      # carries cpu_temp, so the pair reads as one thermal story -- swap the
      # stat here if VRAM pressure turns out to matter more.
      # Both carry an explicit glyph because the defaults made the GPU pair
      # unreadable next to the CPU pair. What the stat glyphs actually resolve
      # to (sysmon_widget.cpp:1086-1116 -> the alias table at
      # render/text/glyph_registry.cpp:69-77):
      #
      #   cpu_usage  "cpu-usage"       -> brand-speedtest   (a speedometer)
      #   cpu_temp   "cpu-temperature" -> flame
      #   ram_used   "memory"          -> cpu               (a CPU chip!)
      #   gpu_usage  "gpu-usage"       -> device-desktop     <- a whole PC
      #   gpu_temp   "temperature"     -> temperature        (weather glyph)
      #
      # So the GPU read as a desktop tower sitting next to a CPU chip that
      # actually meant RAM. Neither said "graphics".
      #
      # There is no GPU glyph to switch to: the bundled Tabler set (5958 names
      # in assets/fonts/tabler.json) has no `gpu`, no `graphics`, and no
      # `brand-nvidia` -- only `brand-amd`, which would be a lie on this card.
      # So device identity is carried by 3D instead, which is what the unit is
      # for, and the pair is legible by adjacency:
      #
      #   CPU -> speedometer + flame
      #   GPU -> 3D badge     + thermometer
      #
      # thermometer (U+EF67) rather than leaving gpu_temp on the default
      # `temperature` (U+EB38): the latter is Tabler's WEATHER glyph and the bar
      # is one capsule away from a weather widget in the control centre.
      # The unread-count badge. Grouped with `notifications` in the `time`
      # capsule rather than getting its own pill: both are counters for things
      # that arrived while you were not looking, so the bell and the feed count
      # belong next to each other -- and it adds no new pill to a bar that
      # already has five.
      #
      # Everything else is left at the manifest defaults, which are already
      # right here:
      #   notify_new                  true  -- wanted, notifications ON
      #   max_notifications_per_cycle 5     -- a per-CYCLE budget shared across
      #                                        all feeds (service.luau:713 makes
      #                                        one and passes it to every feed),
      #                                        not 5 per feed
      #   refresh_minutes             30
      #   show_feed_images            true  -- setting this plugin-level would be
      #                                        pointless: the badge entry
      #                                        redeclares it, and the entry value
      #                                        wins (the shell warns about the
      #                                        shadowing on every start)
      widget.rss = {
        type = "nilsonlinux/rss-notifier:badge";
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

        # Defaults are 0.5/0.3. These were once 0.7/0.5, tuned for BARE text
        # floating on the video, where the background had to be pushed right back
        # to keep anything legible. The glass panel below now carries legibility
        # on its own, so the video can come forward again -- which is the point of
        # having a video at all.
        #
        # blur_intensity is a 3-round Gaussian at blurIntensity*40 px
        # (lock_surface.cpp:1698-1700); tint_intensity is a flat Surface overlay
        # at that alpha (:1004-1018), skipped entirely at 0. These two plus the
        # panel's own background_opacity are the three dials -- move them together.
        blur_intensity = 0.5;
        tint_intensity = 0.35;

        # Inert on this host -- the shell logs "no fprintd device available" on
        # every start. Off, so it stops trying.
        fingerprint = false;
      };

      # The lock screen widget set.
      #
      # This MUST be a fixed point of what normalizeSnapshot converges to, or
      # Noctalia rewrites ~/.local/state/noctalia/settings.toml on every startup
      # and that sidecar -- which deep-merges LAST -- shadows everything here.
      # That is exactly what happened on the first attempt: every value below was
      # silently replaced by defaults.
      #
      # Three rules keep it stable:
      #   1. Declare a login_box for EVERY output. ensureWidgets() walks the
      #      Wayland outputs and manufactures one for any that lacks it -- it does
      #      NOT consult lockscreen.monitors -- and the resulting size increase
      #      triggers a full state write (lockscreen_widgets_controller.cpp:316).
      #   2. Set placement_width/height on everything. Left at the 0.0 default,
      #      remapForOutputChange adopts the output size and reports changed=true.
      #   3. login_box box_height is IGNORED and recomputed from the layout, so it
      #      must already equal defaultPanelHeight or it round-trips as a diff.
      #      compact = 70; regular + session buttons + no info row = 128.
      #      box_WIDTH, by contrast, is kept as declared and only clamped -- and
      #      so are cx/cy. The login box is NOT pinned above the bottom edge the
      #      way lock_surface.cpp:965-966 makes it look; :971-977 reads cx/cy and
      #      overwrites that default. Placement here is real.
      #
      # widget_order is deliberately absent: when present it is an allowlist and
      # silently drops any id not named in it.
      #
      # NOTE: never open the widgets editor (`noctalia msg lockscreen-widgets-edit`,
      # or Settings -> Security -> Lock screen -> Toggle Editor). enterEdit()
      # force-flips `enabled` and persists a full snapshot over this.
      #
      # NOTE: no `button` widgets here. The widget layer receives pointer events
      # while the session is LOCKED (lock_surface.cpp:535, :792-826), so a button's
      # shell command would be runnable from the lock screen.
      lockscreen_widgets = {
        # Required. With this false the host calls hide() and clears every widget
        # instance -- only the login box would render, because LockSurface draws
        # that directly and never consults this gate.
        enabled = true;

        widget = {
          # --- the composition, all on DP-3 -----------------------------------
          # cx/cy are the widget CENTRE in logical pixels, origin top-left, on a
          # canvas that is the monitor (1920x1080). Widgets on the blacked-out
          # side monitors are hidden regardless, so everything lives on DP-3.
          #
          # Setting BOTH box_width and box_height makes the footprint exactly that
          # rectangle, which is what allows the positions to be computed by hand --
          # and it is also what enables content scaling at all.
          #
          # ONE CENTRED MONOLITH: a single glass panel holding time, date and the
          # password field on one axis. Three earlier attempts kept re-tuning the
          # SAME arrangement -- text in the upper-left third, a login strip alone
          # near the bottom edge, 900px of nothing between them -- and only ever
          # changed the sizes and the element count. The arrangement was the
          # problem.
          #
          # Vertical layout on the 1080-tall canvas, every number derived from the
          # panel's top edge at y=316:
          #
          #   316  panel top
          #   364  clock top       (48 padding)
          #   509  clock bottom    (145 box -> ~120px glyphs)
          #   515  date top        (6 gap)
          #   539  date bottom     (24 box -> ~20px)
          #   559  auth card top   (20 gap; RESERVED -- see the login box below)
          #   597  auth card bottom
          #   605  login top       (8 gap, the hard-coded authGap)
          #   675  login bottom    (70, recomputed and unsettable)
          #   724  panel bottom    (49 padding)

          # The glass panel. Noctalia has no container or rectangle widget, so
          # this is an empty label: DesktopWidget::applyBackground
          # (desktop_widget.cpp:226-241) paints the BOX, not the content, whenever
          # box_width and box_height are both > 0 --
          #     boxW = boxed ? m_boxWidth : contentW + 2*pad
          # -- so an empty label with a background is a pure rectangle.
          #
          # It paints BELOW the login box, which is the whole reason this
          # composition is possible. Stacking is explicit z-index, not insertion
          # order: m_backgroundLayer z 0 (lock_surface.cpp:155), m_widgetLayer z 2
          # (:180), m_loginPanel z 2 (:194), m_authPanel z 7 (:428). Paint order is
          # an ascending STABLE sort (render_context.cpp:607), so the z-2 tie
          # resolves to insertion order -- and m_widgetLayer was added first (:181
          # before :184). Hit-testing walks children in REVERSE (node.cpp:469-491),
          # so this cannot steal clicks from the password field either.
          #
          # The id must sort FIRST alphabetically. With widget_order absent the
          # snapshot order comes from toml++'s key-sorted table, and that order is
          # the widget layer's insertion order, which is its z-order -- every
          # widget node gets the default z 0 (lockscreen_widgets_host.cpp:289-292).
          # lock-backdrop < lock-clock < lock-date. There is no per-widget z key in
          # the schema (config_validate.cpp:624-627 is the whole 14-key whitelist).
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
              # Both MUST be present and empty. An ABSENT title falls back to the
              # literal "Title" (desktop_widget_factory.cpp:30-42, :325); an
              # explicit "" does not. Empty text measures to 0x0 and the box is
              # painted regardless, so nothing renders but the rectangle.
              title = "";
              description = "";

              background = true;
              background_color = "surface";
              # The main dial for how much video shows through. Raise it if the
              # hero clock loses contrast on a bright frame.
              background_opacity = 0.55;
              # Clamped 0..32 by the registry, so this is the maximum.
              background_radius = 32.0;
              shadow = false;
            };
          };

          # Time. background=false drops the padding term, so box_height is the
          # font-size dial: contentScaleForBox fits content to the box preserving
          # aspect, and for a wide box height is the binding constraint.
          # Calibrated from the previous 88 -> ~73px, i.e. glyphs ~= 0.83 *
          # box_height, so 145 gives ~120. Width does not bind: "09:41" is ~140px
          # natural at 56px, and 560/140 is far above 145/68.
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
              # Kept even though the panel now carries contrast: at 0.55 opacity a
              # bright video frame still shows through behind the glyphs.
              shadow = true;
            };
          };

          # Date. A `label` cannot do this -- its text is static -- so it is a
          # second clock widget with a date format.
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

          # --- login boxes ----------------------------------------------------
          # One per output, or ensureWidgets manufactures the missing ones and
          # triggers a state write. The two side monitors are blacked out by
          # lockscreen.monitors anyway; disabling them here is belt and braces.
          "lockscreen-login-box@DP-3" = {
            type = "login_box";
            output = "DP-3";
            enabled = true;
            # cx/cy ARE honoured, contrary to how lock_surface.cpp reads at first
            # glance. :965-966 only SEEDS a default (centred, 84px above the bottom
            # edge); :971-977 then reads loginBox->cx/cy and overwrites both with
            # panelX = cx - w/2, panelY = cy - h/2. The on-screen clamp at :981-982
            # has range [16, 994] for a 70px panel here, so a mid-screen value
            # passes through untouched.
            cx = 960.0;
            cy = 640.0;
            # Kept from us verbatim -- ensureWidgets only clamps width, to
            # [kCompactMinPanelWidth, screen - 32] = [240, 1888] here. 560 insets
            # the field 40px from each edge of the 640-wide panel above.
            box_width = 560.0;
            # Ignored and recomputed EVERY FRAME from defaultPanelHeight
            # (lock_surface.cpp:974), so it must already equal that or ensureWidgets
            # rewrites it and the state sidecar shadows this whole block again. For
            # compact that is minPanelHeight with no +spaceMd term:
            # spaceLg*2 + controlHeight = 16*2 + 38 = 70
            # (lockscreen_login_box.cpp:191-193, :219-220).
            box_height = 70.0;
            placement_width = 1920.0;
            placement_height = 1080.0;

            settings = {
              # Just the password row, centred. Compact is not a narrower regular:
              # lock_surface.cpp:956-962 gates the session-button row AND the info
              # row on `regular`, so show_session_buttons / show_media /
              # show_weather below are inert here. Trade accepted -- shutdown and
              # reboot live on SUPER+X, not on the lock screen.
              #
              # Compact also centres the panel's main axis (:1028), which is what a
              # centred composition needs, and regular would force a 720px minimum
              # width -- wider than the panel it has to sit inside.
              layout = "compact";

              # THE trick that makes one unified panel possible. resolveStyle
              # multiplies the fill's alpha by this (lockscreen_login_box.cpp
              # :311-316) and layoutScene passes the same value into the border
              # (lock_surface.cpp:1020-1024), so panel fill AND border both go fully
              # transparent. There is no drop shadow to survive it -- outerShadow
              # defaults false and is never set on m_loginPanel. input_opacity is a
              # separate key applied via setSurfaceOpacity (:1207), so the password
              # field and login button stay at full strength.
              #
              # The cost: the auth status card reuses panelFill/panelOpacity
              # (:1244-1245), so an auth error renders as bare text on the glass
              # rather than in its own chip. It is absolutely placed at
              # panelY - authGap - authH = 605 - 8 - 38 = 559 (:1237-1240,
              # :1254-1258) and never flips below (that needs panelY < 62), which is
              # why 559..597 is left clear above. If bare text reads badly,
              # 0.10-0.15 here brings the card back -- at the price of a faint seam
              # around the password row.
              background_opacity = 0.0;

              # Inert while the opacity is 0, but kept declared so the block stays a
              # fixed point and so raising that opacity gives a sane result.
              background_color = "surface";
              background_radius = 20.0;

              input_opacity = 1.0;
              input_radius = 12.0;
              center_password_text = true;

              show_login_button = true;
              # Renders nothing at rest -- it only appears in the reserved auth band
              # when caps lock is actually on.
              show_caps_lock = true;
              # Off: it renders a permanent "Ready" line, and with it off
              # resolveStatusText returns {} so the auth card is hidden entirely at
              # rest. Errors and the caps-lock warning are NOT gated by it and still
              # show (lock_surface.cpp:1601-1615).
              show_unlock_hint = false;
              show_session_buttons = false;
              show_media = false;
              show_weather = false;
              # MUST stay false. Unlike the rows above, this chip lives INSIDE the
              # password row and is NOT layout-gated (lock_surface.cpp:957,
              # :1043-1044), so compact does not suppress it.
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
        assignments."*" = videoWallpaper;
        # The plugin tracks which outputs it wrapped in a systemd scope here.
        # run_as_systemd is off, so it starts empty rather than absent -- the
        # loader reads decoded.launchedAsSystemd and expects a table.
        launchedAsSystemd = {};
      }
    } "$target"
    fi
  '';

  # The whole palette hangs off a file in ~/.cache, and the failure is silent
  # and does not self-heal.
  #
  # startMpvpaper (mpvpaper_service.luau:413-420) points Noctalia's wallpaper at
  # the PICKER THUMBNAIL for this video, and that still is what the colour
  # generator reads -- so it, not misty-boat.jpg, is the source of every accent
  # in the bar, the window borders and every templated app. Clear ~/.cache and:
  #
  #   * resolveWallpaperGenerated fails to load it, resolveAndSet falls back to
  #     resolveBuiltin, and the palette snaps to Noctalia's builtin scheme;
  #   * on the NEXT start, startMpvpaper's fileExists(thumb) is false, so it
  #     never calls setWallpaper at all and [wallpaper.last] is never corrected.
  #
  # Nothing but opening the picker panel by hand regenerates it. Since the cache
  # filename is a pure function of the video's path, the still can just be
  # committed and restored here, which makes the palette reproducible from the
  # repo instead of an artefact of whatever the picker last did.
  #
  # Seeded only when ABSENT, like the assignment above -- regenerating a
  # thumbnail from the picker stays authoritative once it exists.
  home.activation.noctaliaMpvpaperThumbnail = lib.hm.dag.entryAfter ["writeBoundary"] ''
    thumb="${config.xdg.cacheHome}/noctalia/mpvpaper/${mangleCacheName videoWallpaper}.jpg"
    if [ ! -e "$thumb" ]; then
      run install -Dm644 ${../../assets/mpvpaper-anime-girl-near-car.jpg} "$thumb"
    fi
  '';

  # Plugin settings are a TOML table of their own -- top-level
  # [plugin_settings."author/plugin"], NOT nested under [plugins] -- keyed by the
  # `key` fields in each plugin's plugin.toml. Only deviations from the manifest
  # defaults are set, same rule as the rest of this file.
  programs.noctalia.settings.plugin_settings = {
    # Points the picker at the video half of the wallpaper set. Everything else
    # the plugin defaults to is already right: mute = true (the loops have no
    # audio track anyway) and hardware_decode = true.
    #
    # Two manifest defaults that are NOT what their names suggest, left alone
    # because neither is worth a deviation:
    #   * auto_pause = "full" -- mpvpaper 1.8 has no --auto-mode flag, so the
    #     plugin falls back to a plain --auto-pause (mpvpaper_service.luau
    #     :180-187). "full" and "max" are therefore identical here, and both
    #     mean fullscreen-only. Locking the session is covered by the
    #     session_locked hook above instead.
    #   * extract_last_frame = true -- this gates ONLY the stop/clear still
    #     (<connector>_static.jpg). It is not what the palette generator reads;
    #     that is the ungated picker thumbnail restored above.
    "noctalia/mpvpaper" = {
      video_directory = "/home/${vars.username}/.config/wallpapers/video";
    };

    # TLDR's tech and web-dev editions.
    #
    # The web-dev one MUST be /api/rss/dev, NOT /api/rss/webdev. The obvious
    # spelling is real but answers 308 -> /api/rss/dev, and noctalia.http does
    # not follow redirects: checkFeed (service.luau:703-708) drops any response
    # where res.ok is false and logs NOTHING, so a redirecting URL is a feed
    # that silently never appears. Confirmed the hard way -- `seen` held only
    # the tech feed across two full fetch cycles.
    #
    # So verify a new edition WITHOUT curl -L before adding it; -L follows the
    # redirect and makes a broken URL look fine. Editions that answer 200
    # directly: tech, dev, ai, devops, data, crypto, marketing, design,
    # product, founders, infosec. (`science` is 404 -- it does not exist.)
    #
    # Each RSS item is one day's whole newsletter, not one story, so this is
    # ~2 new items and therefore ~2 notifications per day.
    #
    # No flood on first enable: finalizeFeed (service.luau:600-636) marks every
    # item seen on a feed's FIRST fetch without notifying, without adding to the
    # panel list and without incrementing unread. The consequence is that the
    # panel is EMPTY until TLDR next publishes -- that is the design, not a
    # broken fetch.
    #
    # Only the newest 8 items per feed are ever parsed (MAX_ITEMS in
    # service.luau), which for a daily newsletter is over a week of back issues.
    "nilsonlinux/rss-notifier" = {
      feed_urls = [
        "https://tldr.tech/api/rss/tech"
        "https://tldr.tech/api/rss/dev"
      ];
    };
  };
}
