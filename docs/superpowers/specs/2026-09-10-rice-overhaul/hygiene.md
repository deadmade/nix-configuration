# Correctness and dead config

_Correctness, dead config, and reproducibility_

Nearly every item in the brief checked out, and two were worse than reported: the v4 `{id="control-center";…}` table is not "silently ignored" — `noctalia config export full` proves the entire control-center button is dropped from the bar (`end = ["tray","battery","volume","network","session","clock","notifications"]`), and `~/.local/state/noctalia/settings.toml` currently asserts `[theme] source="custom"` + `builtin`/`community_palette`/`wallpaper_scheme`, which will override and silently defeat the colour domain's `theme.source = "wallpaper"` change. I also found a cross-cutting blocker nobody has flagged: three Noctalia builtin templates (hyprland, starship, gtk3/gtk4) apply themselves by rewriting `~/.config/...` files in place — files Home Manager owns as read-only /nix/store symlinks. starship and hyprland fail outright with EACCES under `set -euo pipefail`; gtk `rm`s the HM symlink and thereby breaks the *next* `nhs`. The cleanup below fixes the dead config, adds a build-time gate so a fourth v4 key cannot sneak in, and makes each template hand-off actually work. Two exploration claims were wrong and I've corrected them: `stylix.targets.hyprlock.enable = false` is a real, valid option (harmless noise, not an eval hazard), and blueman is not a duplicate tray agent (its applet unit is `linked-runtime ignored` and is not running).

## Fatal problems flagged by the verifier

Three items in this design will break the user's system as written, and one silently degrades the desktop.

1. BUILD-BREAKING (item 5). `control_center.calendar = {...}` is added as a sibling of the existing `control_center = { shortcuts = [...]; }` inside the same attrset literal in noctalia.nix. Nix rejects that outright — "error: attribute 'control_center' already defined". This is not a warning; it kills `nix flake check`, `nhs` and `nos` for both desktop hosts. Fix is to nest `calendar` inside the existing `control_center` block (correction supplied in the verdict).

2. SILENTLY DEFEATS ITS OWN PURPOSE (item 3, hyprland half). The proposed `pcall(require, "noctalia")` does not contain the literal string `require("noctalia")`, and the template's guard at assets/templates/hyprland/apply.sh:57 is `grep -qF` — a fixed-string match. The guard fails, apply.sh appends to the /nix/store symlink at ~/.config/hypr/hyprland.lua, and `set -euo pipefail` kills the post_hook on EACCES. The entire colour hand-off to Hyprland fails, and the failure is invisible unless you read the Noctalia log. Use `pcall(function() return require("noctalia") end)` so the literal survives.

3. DEGRADES GTK SILENTLY (item 10). The replacement gtk block carries `enable` and `font` but drops `gtk.theme`, which Stylix currently supplies as adw-gtk3 (verified by eval). With Stylix's gtk target off and no theme declared, adw-gtk3 stops being installed, Noctalia's own gtk/apply.sh:83 `theme_exists "adw-gtk3-dark"` fails, and every GTK3 app falls back to stock Adwaita. Carry `theme = { package = pkgs.adw-gtk3; name = "adw-gtk3-dark"; }`.

4. FRAGILE-BY-ACCIDENT (item 11b, starship). `entryAfter ["writeBoundary"]` only runs after HM's linkGeneration because "linkGeneration" happens to sort before "starshipPrompt". Rename the activation entry to anything alphabetically earlier and the `install` hits the not-yet-removed store symlink with EACCES mid-switch. Anchor it to `["linkGeneration"]` explicitly, and guard the install on the absence of Noctalia's marker so every `nhs` does not wipe the injected palette for up to 30 minutes.

Two rationales are also factually wrong even though their snippets are legal: item 4 claims the launcher currently falls back to "attached" (the real defaults are floating + center, verified at config_types.h:971/979 and in `config export full` lines 491-492, so that change is cosmetic), and item 8's comment calls `stylix.targets.starship.enable = false` revisitable when it is in fact a hard prerequisite for item 11b.

Item 6 is not fatal but is the riskiest construction in the set: it routes a derivation through an attrset-typed option. I proved it evaluates against this flake's own nixpkgs, but a `checks.*` output in flake/modules/per-system.nix gets the same guarantee with none of the exposure.

## Verdicts

### [CONFIRMED] Item 1 — Noctalia state settings.toml overrides the flake and will defeat theme.source = "wallpaper"

**Evidence:** docs/user/configuration/index.mdx:96-105 ("1. Built-in defaults 2. Your *.toml files … 3. GUI-managed overrides in the resolved state directory's settings.toml. Because settings.toml loads last, it wins"). `grep -nE '^\[' ~/.local/state/noctalia/settings.toml` => [lockscreen_widgets]:3, [theme]:94, [wallpaper.default]:102, [wallpaper.last]:105, [wallpaper.monitors.*]:108/111/114. The [theme] block asserts builtin="Noctalia", community_palette="Oxocarbon", wallpaper_scheme="m3-content", source="custom" — none declared by the flake. `noctalia msg color-scheme-get` => `custom stylix`. The drift-detection grep also works: only [theme] and [lockscreen_widgets] survive the `grep -vxE 'wallpaper'` filter, because [wallpaper.*] all reduce to `wallpaper` and the indented sub-tables never match `^\[`.

**Correction:**

The hazard and the activation warning are right, but the manual remediation is worse than necessary. Do NOT stop the daemon and hand-edit TOML — Noctalia ships the supported mutator, verified by `noctalia msg color-scheme-set --help`:

  noctalia msg color-scheme-set wallpaper m3-content   # rewrites [theme] in settings.toml, live, no restart

That single command replaces the whole 'stop noctalia / $EDITOR / start noctalia' block for the [theme] half. Only [lockscreen_widgets] still needs a hand edit (or a one-shot `rm` of that block). Keep the activation warning as written; it is correct and never mutates anything.

### [CONFIRMED] Item 2 — the v4 `{id="control-center";…}` table drops the button entirely; replace with [widget.control-center] custom_image

**Evidence:** src/config/config_types.h:169-173 — `std::vector<std::string> startWidgets/centerWidgets/endWidgets`, so a TOML table is not a widget id. `noctalia config export full` line 35: `end = [ "tray", "battery", "volume", "network", "session", "clock", "notifications" ]` — control-center is gone from the live bar. `noctalia config validate` emits NO warning for it (only 2 warnings, neither about bar.end). `useDistroLogo`: zero hits in src/, example.toml, docs/. Replacement keys are real: example.toml:505-507 `[widget.control-center] custom_image / custom_image_colorize`, backed by src/shell/bar/widgets/control_center_widget_definition.cpp:10 using `glyphButtonFields<Options>()`, which registers `custom_image` (glyph_button_definition.h:26) and `custom_image_colorize` (:31). `nix eval .#nixosConfigurations.deadPc.pkgs.nixos-icons.outPath` resolves, and share/icons/hicolor/scalable/apps/ contains nix-snowflake.svg and nix-snowflake-white.svg.

**Correction:**

Placement only: `widget.control-center = {…}` must sit at the top level of `settings`, a sibling of `bar`/`theme`/`shell`, not nested inside `bar`. The snippet's indentation (shown right after the `};` that closes `bar`) is ambiguous and will read as bar-scoped. Nix accepts the bare hyphen in `widget.control-center` — no quoting needed.

### [WRONG] Item 3 (hyprland half) — the proposed pcall line does NOT satisfy the template's guard; the hook will still die with EACCES

**Evidence:** assets/templates/hyprland/apply.sh:57 — `if ! grep -qF 'require("noctalia")' "$lua_config_file"; then` … :58 `printf '\n%s\n' "$include_line" >>"$lua_config_file"`. `-F` is a FIXED-STRING match for the literal `require("noctalia")`. The design's proposed line is `local ok, noctalia = pcall(require, "noctalia")`, which contains `pcall(require, "noctalia")` — the literal substring `require("noctalia")` never appears. The guard therefore fails, the hook appends to `~/.config/hypr/hyprland.lua`, and `ls -la ~/.config/hypr/hyprland.lua` shows it is a symlink into /nix/store/gx81c3j9gw0rm3rj508ypcypvgjxdqld-home-manager-files/. Under `set -euo pipefail` (apply.sh:2) the redirect fails with EACCES and the whole post_hook aborts. Everything else in the item checks out: apply.sh:45 apply_lua, hyprland/hyprland.lua returns `{colors, apply_theme}`, builtin.toml [templates.hyprland] uses input/output_path_dynamic + apply post_hook.

**Correction:**

The include line must contain the literal `require("noctalia")` while still being crash-safe. Wrap the require in a closure instead of passing it to pcall as a function value:

      -- Noctalia colour template. This line must contain the literal
      -- require("noctalia") so apply.sh:57's `grep -qF` guard matches and its
      -- append to our read-only /nix/store hyprland.lua becomes a no-op.
      local ok, noctalia = pcall(function() return require("noctalia") end)
      if ok and noctalia.apply_theme then noctalia.apply_theme() end

Also resolve the module-lookup ambiguity: `~/.config/hypr/noctalia/` already exists (a v4 orphan holding noctalia-colors.conf). The Hyprland binary carries both `.lua` and `init.lua` as separate resolver suffixes (strings on .Hyprland-wrapped, `.lua` immediately preceding `init.lua`), so `noctalia.lua` should win — but item 17's `rm -rf ~/.config/hypr/noctalia` is a prerequisite, not a tidy-up. Sequence it first.

### [CONFIRMED] Item 3 (gtk half) — the gtk template does rm the HM symlink and breaks the next nhs

**Evidence:** assets/templates/gtk/apply.sh:41-50 — `if [ -L "$gtk_css" ]; then resolved=$(readlink -f …); if [ -w "$resolved" ]; then target=…; else rm "$gtk_css"; fi; fi` then `printf … > "$target"`. `ls -la ~/.config/gtk-3.0/gtk.css` is an HM store symlink, and /nix/store is not writable, so the `rm` branch is taken. builtin.toml [templates.gtk3]/[templates.gtk4] both call `gtk/apply.sh {{ mode }}` with hook_async = false. Note the design understates it slightly: apply.sh:36 `content=$(cat "$gtk_css")` reads Stylix's generated CSS first and freezes it into the new plain file, so you get Stylix colours permanently baked in under the Noctalia @import until you delete the file by hand.

**Correction:**

None to the mechanism. Add one step to the manual checklist: after `stylix.targets.gtk.enable = false` lands and HM stops managing the path, `rm -f ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css` once, so apply.sh takes its `else` branch (:54, create fresh with only the @import) rather than carrying frozen Stylix CSS forward.

### [WRONG] Item 4 — launcher_placement="centered" is invalid, but the rationale is wrong: the fallback is floating+center, not attached

**Evidence:** The invalidity is real: `noctalia config validate` => `config.toml:70:22: shell.panel.launcher_placement: unknown value "centered"`; enum bound at src/config/schema/config_schema.cpp:1334 to kPanelPlacements, defined at src/config/config_types.h:881-884 as exactly {attached, floating}. `launcher_position` is real (config_schema.cpp:1340; example.toml:68; kPanelPositions at config_types.h:888-892 = auto|center|top_left|top_center|top_right|center_left|center_right|bottom_left|bottom_center|bottom_right). BUT the claim "which is why the launcher currently falls back to the default attached placement" is false. config_types.h:971 `PanelPlacement launcherPlacement = PanelPlacement::Floating;` and :979 `std::string launcherPosition = "center";`. `noctalia config export full` lines 491-492 confirm the LIVE effective values are already `launcher_placement = "floating"` and `launcher_position = "center"`.

**Correction:**

Keep the snippet exactly as proposed — it is legal and correct — but restate the impact honestly. This change is cosmetic: it silences a validator warning and makes the flake state what is already true. It changes nothing about where the launcher opens, so do not sell it as fixing launcher placement, and do not let it justify the item's 'medium' impact.

### [WRONG] Item 5 — calendar.cards is dead and control_center.calendar is the right home, but the Nix snippet will not evaluate

**Evidence:** The v5 facts are right: `noctalia config validate` => `config.toml:27:1: calendar.cards: unknown setting`; the only calendar binding under control_center is config_schema.cpp:491 `subTable(&ControlCenterConfig::calendarTab, "calendar", calendarTabSchema())` with fields at :476-477; example.toml:253-255; defaults at config_types.h:1577-1579 (showEventsCard=true, showWeekNumbers=false), matching `noctalia config export full` lines 86-87. The Nix is the problem: noctalia.nix already defines `control_center = { shortcuts = [...]; };` inside `settings`. Adding a sibling `control_center.calendar = {…};` in the SAME attrset literal is a hard Nix eval error — `error: attribute 'control_center' already defined`. That kills `nix flake check`, `nhs`, and `nos`.

**Correction:**

Merge it into the existing block rather than adding a second binding:

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

        # v5 has no [[calendar.cards]]. Top-level [calendar] is the CalDAV/Google
        # sync service; the clock-popup calendar lives here.
        calendar = {
          show_events_card = false;
          show_week_numbers = true;
        };
      };

Also: `power_profile` is in that shortcut list and deadPc runs no power-profiles-daemon and no upower, so that tile is inert on the desktop — orthogonal to this item, but it is the same block.

### [UNCERTAIN] Item 6 — the build-time strict gate: the premise is right and the derivation-as-settings trick does evaluate, but it is the riskiest shape available

**Evidence:** Premise confirmed: `noctalia config validate; echo $?` => `exit=0` with both warnings present; `noctalia config validate --help` => "Exits 1 if any error is found". nix/home-module.nix checkConfig defaults true and its runCommand runs exactly `noctalia config validate ${rawConfig}`. `lib.getExe` works — package.meta.mainProgram evaluates to "noctalia". The `settings` type is `oneOf [tomlFormat.type str path]`, and tomlFormat.type's check is `isAttrs`, which a derivation satisfies — so I tested it end to end against THIS flake's nixpkgs: evalModules with `config.foo = pkgs.writeText …` under that exact type returns `/nix/store/…-x.toml`. It works. What I could not verify is that it keeps working through the full HM eval path (`generateConfig`'s isStorePath branch, then `xdg.configFile.source`, then the unit's X-Restart-Triggers).

**Correction:**

Prefer a shape that does not push a derivation through an attrset-typed option. Keep `settings` a plain attrset and `checkConfig = true`, and put the strict gate where `nix flake check` already looks — flake/modules/per-system.nix, which this repo already owns:

  # flake/modules/per-system.nix, in perSystem = {pkgs, self', ...}:
  checks.noctalia-config = pkgs.runCommand "noctalia-config-strict" {} ''
    cfg=${inputs.self.homeConfigurations."deadmade@deadPc".config.xdg.configFile."noctalia/config.toml".source}
    log=$(${lib.getExe inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default} \
            config validate "$cfg" 2>&1) || { printf '%s\n' "$log" >&2; exit 1; }
    printf '%s\n' "$log"
    printf '%s\n' "$log" | grep -q WARN && {
      echo "noctalia: validate emitted warnings; treating as errors" >&2; exit 1; }
    touch $out
  '';

Same guarantee, zero risk to the HM option type, and it fires under `nix flake check` where the repo's CI story already lives. If you keep the design's version instead, smoke-test with `nix eval .#homeConfigurations."deadmade@deadPc".config.home.activationPackage` BEFORE you `nhs`.

### [CONFIRMED] Item 7 — dead variables.nix inherit, stale 0.55.x comment, unused lib/host args

**Evidence:** modules/home-manager/windowManager/hyprland/default.nix:1-11 — `{lib, host, pkgs, inputs, ...}: let inherit (import ../hosts/${host}/variables.nix) ; in with lib; {…}`. `inherit (e) ;` with an empty name list never references `e`, so the lazy `host` arg is never forced. flake/modules/home.nix:13-16 sets extraSpecialArgs = { inherit inputs vars systems; outputs = projectOutputs; } — no `host`. `grep -rn "_module.args"` over the repo (excluding .direnv) hits only flake/modules/exports.nix:11 and flake/modules/constants.nix:7, neither of which defines `host`. Path is doubly dead: ../hosts/ from that file is modules/home-manager/windowManager/hosts/, which does not exist. Version: `nix eval …config.wayland.windowManager.hyprland.package.version` => 0.56.2. And `lib` has no consumer once the inherit and `with lib;` go.

**Correction:**

None. One sequencing note the design already makes but that is worth hardening: this snippet simultaneously deletes hyprshot, wofi-emoji and `services.network-manager-applet.enable`, which are items 13 and 14's business. If those items are cut, this snippet silently cuts them anyway.

### [CONFIRMED] Item 8 — stylix.targets.hyprlock.enable = false is valid and inert

**Evidence:** stylix source has modules/hyprlock/hm.nix and modules/hyprlock/meta.nix. `nix eval .#homeConfigurations."deadmade@deadPc".config.stylix.targets.hyprlock.enable` => false, evaluated cleanly. The exploration brief's implied eval hazard is not real; the design's correction of it is right.

**Correction:**

One thing the item gets wrong in its comment: `starship.enable = false` is described as 'revisited once Noctalia owns the prompt palette'. It is not revisitable — it is load-bearing. Stylix's starship target writes `programs.starship.settings.palette` and `palettes.base16` (modules/starship/hm.nix:5-7). If it were ever re-enabled, HM's `hasGeneratedConfig = cfg.settings != {} || cfg.presets != []` flips true, HM writes ~/.config/starship.toml back into the store, and item 11's whole approach dies. Change the comment to say the target MUST stay false.

### [CONFIRMED] Item 9 — deadConvertible's wpaperd block is dead

**Evidence:** `nix eval .#homeConfigurations."deadmade@deadConvertible".config.services.wpaperd.enable` => false. hosts/deadConvertible/home.nix defines only `services.wpaperd.settings`, never `enable`. `config` is used nowhere else in that file (its only reference is `config.xdg.configHome` inside the wpaperd block), so dropping it from the module header is correct.

**Correction:**

None.

### [WRONG] Item 10 — gtk.enable is redundant today and becomes load-bearing, but the replacement block silently uninstalls the GTK theme

**Evidence:** The premise checks out: stylix modules/gtk/hm.nix:33 sets `gtk.enable = true;` unconditionally, and eval confirms gtk.enable = true on BOTH hosts. But the replacement carries only `enable` and `font`, and Stylix's gtk target is also what supplies the theme: `nix eval …config.gtk.theme` => {"name":"adw-gtk3","package":"/nix/store/xjd3j50qzfvvvkjcc35khqjllnlz9599-adw-gtk3-6.5"}. Turn the target off with the design's block and gtk.theme goes null, HM stops installing adw-gtk3 into ~/.local/share/themes, and Noctalia's own apply.sh:83-88 `theme_exists "adw-gtk3-dark"` then fails and logs "Theme 'adw-gtk3-dark' not found, skipping GTK theme set". GTK3 apps drop to stock Adwaita with a Noctalia @import bolted on. `nix eval …config.gtk.iconTheme` => null, so there is no icon theme to lose, but there is nothing to gain either.

**Correction:**

Carry the theme across, not just the font:

  gtk = {
    enable = true;
    font = {
      inherit (config.stylix.fonts.sansSerif) package name;   # Montserrat
      size = config.stylix.fonts.sizes.applications;          # 12
    };
    # Stylix's gtk target set this; Noctalia's apply.sh:83 looks for exactly
    # "adw-gtk3-dark" via theme_exists() and silently skips the theme when it
    # is absent, so it has to keep being installed and named here.
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
  };

Also: stylix.nix currently takes `{pkgs, inputs, ...}` and this needs `config` added — the design says so, do not lose it.

### [CONFIRMED] Item 11 — link ~/.face from the committed avatar and enable accounts-daemon

**Evidence:** `ls ~/.face` => No such file or directory. `ls modules/home-manager/assets/` => avatar.jpg (15k). `noctalia config export full`:424 `avatar_path = "/home/deadmade/.face"`. AccountsService claim is in two places: docs/user/control-center/index.mdx:79 and docs/user/configuration/shell.mdx:188 ("If accountsservice is missing or disabled … login greeters that depend on AccountsService will not see that image"). `nix eval .#nixosConfigurations.deadPc.config.services.accounts-daemon.enable` => false, and the option is defined. Relative path checks out: from modules/home-manager/windowManager/hyprland/, `../../assets/avatar.jpg` resolves to modules/home-manager/assets/avatar.jpg.

**Correction:**

None.

### [UNCERTAIN] Item 11b — starship: the EACCES diagnosis is right; the activation seed has an ordering and a clobber problem

**Evidence:** Diagnosis confirmed: assets/templates/starship/apply.sh:148 `cat "$tmp_file" >"$config_file"`, where config_file comes from `discover_starship_config` reading STARSHIP_CONFIG; `env | grep STARSHIP` => STARSHIP_CONFIG=/home/deadmade/.config/starship.toml, and `ls -la` shows it is a store symlink → write-through EACCES under `set -euo pipefail` (apply.sh:2). HM's guard is real: starship.nix:19 `hasGeneratedConfig = cfg.settings != {} || cfg.presets != []` and :141 `file.${cfg.configPath} = mkIf hasGeneratedConfig …`, with :139 setting sessionVariables.STARSHIP_CONFIG unconditionally. All five toml defects are real: `purple` used at lines 24/26/178/188/189 but defined only in the unreachable [palettes.gruvbox_dark] (line 31); `#83a598` and `color_bg3` at line 172; `orange = "#cba6f7"` at line 47; `fg:creen` at line 187; `palette = 'catppuccin_mocha'` at line 29. What I cannot confirm: the activation ordering. `home.activation.starshipPrompt` uses entryAfter ["writeBoundary"], the same anchor HM's own `linkGeneration` uses. It happens to work only because HM's DAG breaks ties in attrнабор order and "linkGeneration" sorts before "starshipPrompt" — rename the entry to anything starting a-k and the install runs before HM removes the old store symlink, and `install` write-through gives EACCES.

**Correction:**

Pin the dependency explicitly and stop clobbering Noctalia's injected block on every switch:

  home.activation.starshipPrompt =
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      dest="${config.xdg.configHome}/starship.toml"
      # Only seed when the file is missing or has no Noctalia palette block --
      # apply.sh re-injects between its markers and preserves the body, so an
      # unconditional install would wipe the palette until the next theme change
      # (up to 30 min with interval_seconds = 1800).
      if [ ! -e "$dest" ] || ! ${pkgs.gnugrep}/bin/grep -q 'NOCTALIA STARSHIP PALETTE' "$dest"; then
        run ${pkgs.coreutils}/bin/install -Dm644 ${promptBody} "$dest"
      fi
    '';

And after the first switch, nudge the template once rather than waiting for a wallpaper rotation: `noctalia msg color-scheme-set wallpaper m3-content` re-renders and re-applies every enabled template.

### [CONFIRMED] Item 12 — the three hand-installed plugins are v4 QML and inert; plugins.enabled/auto_update are real keys

**Evidence:** `ls -R ~/.config/noctalia/plugins` => ip-monitor, news, privacy-indicator, each with Main.qml/BarWidget.qml/Panel.qml/manifest.json and no plugin.toml. manifest minNoctaliaVersion: ip-monitor 4.4.3, news 3.6.0, privacy-indicator 3.6.0. `~/.local/share/noctalia/` does not exist at all. Schema keys are real: config_schema.cpp:526 `field(&PluginsConfig::enabled, "enabled")` and :528-547 the custom auto_update parser whose error text is literally "expected all|official|none". `noctalia config export full`:406-408 => `[plugins] auto_update = "all"` / `enabled = []`, confirming the default is "all".

**Correction:**

None to the mechanism. Two notes: `enabled = []` is already the default so only `auto_update = "none"` changes anything; and `noctalia msg plugins list` (confirmed present in `noctalia msg --help`:79) is a read-only IPC call, so the belt-and-braces check the item declined to run is in fact safe to run before deleting.

### [CONFIRMED] Item 13 — nm-applet is the only true duplicate; blueman and solaar are not

**Evidence:** `pgrep -a nm-applet` => 4474 …/network-manager-applet-1.36.0/bin/nm-applet. `pgrep -af solaar` => 4472 solaar --window hide --battery-icons regular. `pgrep -af blueman` => no blueman process. `systemctl --user list-unit-files | grep -iE 'blueman|network-manager|solaar'` => blueman-applet.service `linked-runtime ignored`, blueman-manager.service `linked-runtime ignored`, network-manager-applet.service `enabled ignored`, solaar.service `enabled ignored`. `systemctl --user list-units --state=running` shows only network-manager-applet.service and solaar.service. The autostart generator does emit `app-blueman@autostart.service (generated -)`, but it is not running, so the conclusion holds. `services.network-manager-applet.enable = true` is at modules/home-manager/windowManager/hyprland/default.nix:25.

**Correction:**

None.

### [CONFIRMED] Item 14 — drop hyprshot and wofi-emoji for Noctalia's built-ins

**Evidence:** Every replacement command exists in the live binary: `noctalia msg --help` lines 82-84 => screenshot-annotate, `screenshot-fullscreen [mode]` ("pick" / "all"), screenshot-region; line 77 => `panel-toggle <id> [context]` with the help text naming "launcher /emo" explicitly. docs/user/ipc/media-and-ui.mdx:117-122 covers region/fullscreen/pick/output/all/annotate; :113 names the wlr-screencopy-unstable-v1 requirement, which Hyprland provides. example.toml:94-95 confirms the emoji provider at prefix "emo" under provider_prefix "/". `which hyprpicker` => not found; `nix eval .#nixosConfigurations.deadPc.pkgs.hyprpicker.name` => hyprpicker-0.4.7, so the replacement package resolves. No keybind collisions: the live hyprland.lua binds SUPER+SHIFT+S (hyprshot, being replaced), SUPER+X (wofi-emoji, being replaced), SUPER+SHIFT+Q/L and SUPER+P — SUPER+SHIFT+A and SUPER+SHIFT+P are both free. `grep -rn wofi` finds no programs.wofi anywhere, so Stylix's wofi target never fired.

**Correction:**

None. The single-quote form in the Lua string is required as the item says — `hl.dsp.exec_cmd('noctalia msg panel-toggle launcher "/emo"')` — and is valid inside a Nix '' block.

### [CONFIRMED] Item 15 — deadConvertible's hand-rolled portals and pipewire are drift; adding base.nix requires deleting them

**Evidence:** hosts/deadConvertible/config.nix imports desktop.bluetooth/packages/stylix/vpn/ai/jetbrains/tailscale/wayvnc but NOT desktop.base, then re-declares environment.pathsToLink = ["/share/zsh"] (line 29), the identical xdg.portal extraPortals (lines 45-56) with `common.default = "hyprland"` where modules/nixos/desktop/base.nix:13 has ["hyprland" "gtk"], and the same pipewire block (lines 61-73) with alsa.support32Bit = false against base's true. Both divergent values are scalar options merged by mergeEqualOption, so importing base without deleting them is a hard "conflicting definition values" eval error, exactly as the item warns. deadPc reaches base via outputs.nixosProfiles.desktopAll. flake/lib/registry.nix confirms `outputs.nixosModules.desktop.base` is the right attr path (filename minus .nix).

**Correction:**

None.

### [CONFIRMED] Item 16 — reconcile vars; fix fileManager = "thunar"

**Evidence:** `grep -rn "vars\." --include="*.nix"` excluding .direnv returns exactly 9 hits across 5 files, all of them username/gitUsername/gitEmail: flake/modules/home.nix:26, hosts/deadWsl/config.nix:23, noctalia.nix:84 and :174, modules/nixos/core/user.nix:9/11/19, modules/home-manager/core/git.nix:8/9. browser/terminal/keyboardLayout/consoleKeyMap (flake/modules/constants.nix:11-14) have zero consumers. The values also lie: config.nix:8 hardcodes terminal = "ghostty", :81 and :91 launch librewolf not helium, :15 hardcodes kb_layout = "de". fileManager: config.nix:9 `fileManager._var = "thunar"`; `grep -rn "nautilus|thunar"` finds thunar ONLY at that line and nautilus only at modules/nixos/desktop/packages.nix:22 — so SUPER+E (config.nix:87) currently execs a binary that does not exist.

**Correction:**

None. Note that fixing `fileManager._var` alone changes the generated hyprland.lua `local fileManager = "nautilus"`, which is the whole fix — no other file needs touching.

### [CONFIRMED] Item 17 — launch_apps_as_systemd_services and polkit_agent

**Evidence:** Both keys exist: config_schema.cpp:1575 `field(&ShellConfig::launchAppsAsSystemdServices, "launch_apps_as_systemd_services")` and :1568 `field(&ShellConfig::polkitAgent, "polkit_agent")`. `noctalia config export full` line 439 => false, line 444 => false. The recommendation is upstream's own: docs/user/getting-started/nixos.mdx:306 — "When using the service, it is recommended to enable launch_apps_as_systemd_services, otherwise any apps launched by Noctalia will be terminated when the service restarts." nix/home-module.nix sets X-Restart-Triggers on config.toml plus every customPalettes file, and this config sets systemd.enable = true. `grep -rn polkit` over the repo finds only security.polkit.enable in modules/nixos/core/security.nix — no agent package anywhere.

**Correction:**

None.

### [CONFIRMED] Item 18 — manual checklist of unmanaged files

**Evidence:** `head -8 ~/.config/hypr/hyprland.conf` => "# This config is a STUB! This should never be generated." plus autogenerated = 1; it is a real file (541 bytes, 20 Jun 11:24), not a symlink. hyprland.conf.backup is a real file (4.9k, 6 Mär). `cat ~/.config/hypr/noctalia/noctalia-colors.conf` => v4 hyprlang orphan with $primary = rgb(fff59b) / $surface = rgb(070722). `ls ~/.config/noctalia/colorschemes/` => empty. hyprpaper.conf is confirmed an HM symlink, and hyprpaper is genuinely running (`pgrep -af hyprpaper` => 4473 hyprpaper-0.8.4) because `nix eval …config.services.hyprpaper.enable` => true, driven by stylix modules/hyprland/hm.nix:51-54 which sets services.hyprpaper.enable when cfg.hyprpaper.enable, and `nix eval …config.stylix.targets.hyprland.hyprpaper.enable` => true.

**Correction:**

Promote `rm -rf ~/.config/hypr/noctalia` from tidy-up to prerequisite — see item 3. A stale `noctalia/` directory sitting next to the `noctalia.lua` the template will write is a module-resolution ambiguity for `require("noctalia")`, and it must go before the hyprland template is first enabled, not after.

### [CONFIRMED] Cross-cutting — the design's open question 2 (Hyprland reload on noctalia.lua change) has an answer in the source

**Evidence:** `noctalia config export full` lines 159-176 show a real [hooks] section with sixteen keys, including `colors_changed = []`, `wallpaper_changed = []` and `theme_mode_changed = []`. Confirmed live in the effective config, not just in prose.

**Correction:**

The hook key the item did not want to guess at is `colors_changed`:

      hooks = {
        # The hyprland template rewrites ~/.config/hypr/noctalia.lua, but Hyprland
        # only require()s it once at config load, so border colours would lag a
        # wallpaper rotation without this.
        colors_changed = ["hyprctl reload"];
      };

UNVERIFIED and worth a manual test before committing: `hyprctl reload` re-executes the whole hyprland.lua, including the `hl.bind` loop and `hs.config`. I could not confirm whether Hyprland clears its keybind table on reload; if it does not, every wallpaper rotation accumulates duplicate binds. Test with a single manual `hyprctl reload` and check `hyprctl binds | wc -l` before and after before wiring this to a 30-minute timer.

## Proposed changes

### 1. (high) Noctalia's GUI state file silently overrides the flake — and will defeat theme.source = "wallpaper"

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Verified precedence from docs/user/configuration/index.mdx: "1. Built-in defaults 2. Your *.toml files ... 3. GUI-managed overrides in the resolved state directory's settings.toml. Because settings.toml loads last, it wins." `noctalia config export merged` proves the drift is live right now: [theme] comes back with builtin="Noctalia", community_palette="Oxocarbon", wallpaper_scheme="m3-content" — three keys the flake never declares — plus source="custom". The moment the colour domain sets theme.source = "wallpaper" in Nix, the state file's "custom" wins and the whole Material You migration will appear to do nothing. This is the single highest-value item in the cleanup. The file also churns constantly: it rewrote itself mid-session as the 300s wallpaper rotation fired. So the policy is NOT "delete the state file" (that would nuke clipboard history, notification history, plugin caches, and wallpaper_shuffle state); it is (a) surgically clear the two stale blocks now, (b) accept [wallpaper.*] as genuine runtime state Nix cannot own, (c) get told at activation time when anything else drifts. I use plain echo rather than HM's warnEcho so the snippet does not depend on an activation-lib helper name.

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/configuration/index.mdx lines 98-115 and 146; `noctalia config export merged` lines 156-166; live diff of ~/.local/state/noctalia/settings.toml during this session

**Risk:** The manual edit needs noctalia stopped or it may rewrite the file back. The activation warning is advisory only and never mutates state — worst case it prints a false positive for a table you deliberately manage via the GUI.

```nix
# --- one-time manual step (you must run this; I am read-only) -------------
#   systemctl --user stop noctalia
#   $EDITOR ~/.local/state/noctalia/settings.toml
#     delete the whole [theme] block          (shadows the flake's theme.source)
#     delete the whole [lockscreen_widgets] block (stale DP-2/DP-3/HDMI-A-1 layouts)
#     KEEP config_version and [wallpaper.*]   (real runtime state)
#   systemctl --user start noctalia
# -------------------------------------------------------------------------

# Noctalia loads: built-in defaults -> ~/.config/noctalia/*.toml (this file)
# -> ~/.local/state/noctalia/settings.toml. The state file loads LAST and
# wins, so one GUI tweak silently beats the flake with no warning anywhere.
# We cannot make it stop winning, so make it visible on every `nhs`.
home.activation.noctaliaStateDrift =
  lib.hm.dag.entryAfter ["writeBoundary"] ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
    if [ -f "$state" ]; then
      drift=$(${pkgs.gnugrep}/bin/grep -oE '^\[+[a-z_]+' "$state" \
              | ${pkgs.coreutils}/bin/tr -d '[' \
              | ${pkgs.coreutils}/bin/sort -u \
              | ${pkgs.gnugrep}/bin/grep -vxE 'wallpaper' || true)
      if [ -n "$drift" ]; then
        echo "WARNING: noctalia GUI overrides in $state shadow this flake:"
        echo "$drift" | while read -r t; do echo "    [$t]"; done
        echo "    inspect with: noctalia config export merged"
        echo "    then promote the keepers into noctalia.nix and delete them there"
      fi
    fi
  '';
```

### 2. (high) The dead v4 bar entry doesn't just lose useDistroLogo — it drops the control-center button entirely

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Stronger than the brief claims, and provable. `BarConfig::startWidgets/endWidgets` are `std::vector<std::string>` (src/config/config_types.h:169), so a TOML table in that array is not a widget id at all. `noctalia config validate` emits NO warning for it, and `noctalia config export full` shows the effective list as `end = ["tray","battery","volume","network","session","clock","notifications"]` — the button is gone from the bar today. `control-center` is still a valid v5 id (example.toml:59, :368). `useDistroLogo` does not exist anywhere in v5; the replacement is `[widget.control-center] custom_image` (example.toml:505-507). nix-snowflake.svg is confirmed present in pkgs.nixos-icons. custom_image_colorize = true makes it follow the generated palette rather than staying Nix-blue, which matters once the wallpaper drives the colours.

**Verified against:** `noctalia config export full` (effective bar.default.end); .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/src/config/config_types.h:169; example.toml:59,368,505-507; `ls /nix/store/...-nixos-icons-*/share/icons/hicolor/scalable/apps/`

**Risk:** pkgs.nixos-icons must be resolvable from the HM pkgs (it is — plain nixpkgs). If you prefer the light glyph on a dark bar, swap to nix-snowflake-white.svg and set custom_image_colorize = false.

```nix
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

      # v5 has no `useDistroLogo` (it was a v4 key, and a table in `end` is
      # dropped outright because the section lists are vector<string>).
      # The button's face is set per-widget instead.
      widget.control-center = {
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        custom_image_colorize = true; # tint it with the active palette
      };
```

### 3. (high) Three Noctalia builtin templates cannot apply themselves onto Home-Manager-owned files

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** This blocks the colour domain and nobody has flagged it. Every Noctalia template renders to a side file, then runs a post_hook that edits the *real* config in place. Three of those real configs are read-only /nix/store symlinks here. (1) hyprland: assets/templates/hyprland/apply.sh `apply_lua()` does `printf … >> "$config_dir/hyprland.lua"` — hyprland.lua is a store symlink, so under `set -euo pipefail` the hook dies with EACCES. Fix: declare the include line ourselves; the hook's guard is `grep -qF 'require("noctalia")'`, so a matching line makes the hook a verified no-op. pcall is required because ~/.config/hypr/noctalia.lua does not exist until the template renders once, and a bare `require` of a missing module aborts the whole Hyprland config. Hyprland already puts ~/.config/hypr on the Lua package.path (that is how the vendored hyprsplit resolves), so `require("noctalia")` will find it. (2) starship: see the starship item. (3) gtk3/gtk4: assets/templates/gtk/apply.sh explicitly handles the read-only case by `rm`-ing the symlink and writing a plain file — so it succeeds once, and then the NEXT `home-manager switch` aborts because an unmanaged file sits where HM wants its link. That one is fixed by turning stylix.targets.gtk off (colour domain) so HM stops writing gtk.css at all.

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/assets/templates/hyprland/apply.sh (apply_lua), assets/templates/hyprland/hyprland.lua (returns {colors, apply_theme}), assets/templates/gtk/apply.sh (ensure_gtk_css_import: `rm "$gtk_css"` on a non-writable symlink), assets/templates/builtin.toml:168-172; `ls -la ~/.config/hypr/hyprland.lua ~/.config/gtk-3.0/gtk.css` (both -> /nix/store/…-home-manager-files/)

**Risk:** Noctalia's apply_theme() calls hl.config() after our own settings, so it wins on border colours — which is the intent, but it means stylix.targets.hyprland must be turned off or you get two writers. Unverified: whether Hyprland re-reads a require()d module on change, so colours may lag a wallpaper rotation until the next reload.

```nix
    extraConfig = ''
      -- hyprsplit: awesome/dwm-like per-monitor workspaces (Lua library)
      local hs = require("hyprsplit")
      hs.config({ num_workspaces = 10 })

      -- Noctalia colour template. Its post_hook wants to append this exact
      -- require() to hyprland.lua, but ours is a /nix/store symlink and the
      -- append would die with EACCES under `set -euo pipefail`. Declaring it
      -- here satisfies the hook's `grep -qF 'require("noctalia")'` guard, so
      -- the hook becomes a no-op and only renders ~/.config/hypr/noctalia.lua.
      -- pcall: that file does not exist until the template renders once.
      local ok, noctalia = pcall(require, "noctalia")
      if ok then noctalia.apply_theme() end

      -- Autostart
      -- ... (rest unchanged)
    '';
```

### 4. (medium) launcher_placement = "centered" is an invalid enum — the right pair is floating + launcher_position

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `noctalia config validate` reports it verbatim: `config.toml:70:22: shell.panel.launcher_placement: unknown value "centered"`. The schema binds it to kPanelPlacements (config_schema.cpp:1334) and example.toml:63 documents exactly two values, `attached | floating`. The intent (a launcher centred on screen rather than hanging off the bar) is expressed in v5 by a *second* key: `launcher_position = "center"`, which example.toml:69 notes is floating-only. So this is not a rename — it is one bad value plus one missing key, which is why the launcher currently falls back to the default attached placement.

**Verified against:** `noctalia config validate` warning text; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/example.toml:63,69; src/config/schema/config_schema.cpp:1334

**Risk:** A floating centred launcher on a 5760x1080 canvas lands on whichever output Noctalia considers focused; if it picks the wrong monitor, `open_near_click_launcher = true` anchors it to the bar click instead.

```nix
        panel = {
          launcher_placement = "floating"; # attached | floating
          launcher_position = "center";    # floating only; auto | center | top_left | …
        };
```

### 5. (medium) calendar.cards is an unknown v5 setting; the surviving controls are under [control_center.calendar]

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `noctalia config validate` reports `config.toml:27:1: calendar.cards: unknown setting`, and grepping the v5 schema for `cards` returns nothing — the only `calendar` binding is `subTable(&ControlCenterConfig::calendarTab, "calendar", …)` at config_schema.cpp:491. In v5, `[calendar]` is the CalDAV/Google sync service (default enabled=false, example.toml:245-249), which is a completely different thing from the popup. The two knobs that remain are `show_events_card` and `show_week_numbers` (example.toml:253-255). Note the honest gap: there is no v5 way to remove the month grid from the clock popup, so the original v4 intent is not fully reproducible — the closest is `[widget.clock] interactive = false`, which also disables the tooltip. I have not proposed that; see open questions. The weather card is already gated by the existing `weather.enabled = false`, so that third card needs nothing.

**Verified against:** `noctalia config validate` warning text; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/src/config/schema/config_schema.cpp:491; example.toml:245-255

**Risk:** None — both keys are documented defaults being flipped.

```nix
      # v5 has no [[calendar.cards]]. [calendar] is the CalDAV/Google sync
      # service (off by default); the clock-popup calendar is configured here.
      # The weather card is already gated by `weather.enabled = false` below.
      control_center.calendar = {
        show_events_card = false;  # no accounts configured, so the card is empty
        show_week_numbers = true;  # ISO 8601 week numbers in the month grid
      };
```

### 6. (medium) Make warnings fail the build so a fourth v4 key cannot sneak in

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** This is the systemic fix for the three items above, and it is why they survived a migration in the first place. `programs.noctalia.checkConfig` already defaults to true and already runs `noctalia config validate` at build time (nix/home-module.nix) — but `noctalia config validate --help` states it "Exits 1 if any *error* is found", and unknown settings and bad enum values are WARN, not error. I confirmed the exit code is 0 with both warnings present. So the build has been green for months while three keys did nothing. `programs.noctalia.settings` accepts a path/store path as well as an attrset (the type is `oneOf [tomlFormat.type str path]` and generateConfig short-circuits on `lib.isStorePath`), so we can hand it a derivation that has already been validated strictly.

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/nix/home-module.nix (checkConfig block + generateConfig's `lib.isStorePath` branch + settings option type); `noctalia config validate --help`; observed exit 0 with two WARNs present

**Risk:** A future Noctalia release that emits an advisory WARN you cannot fix would block the build until you drop this. Mitigation is a one-line revert to checkConfig = true. Also, migration warnings for legacy-but-still-accepted keys become hard errors — which is arguably the point.

```nix
# in the `let` block at the top of the file
let
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  settings = { /* the attrset that is `settings = { … }` today */ };
  rawConfig = (pkgs.formats.toml {}).generate "noctalia-config.toml" settings;
  # programs.noctalia.checkConfig runs `noctalia config validate`, which exits 0
  # on WARN. Unknown settings and bad enum values are WARN -- which is exactly
  # how three v4 keys survived the v5 migration with a green build. Re-run it
  # ourselves and treat any warning as a build failure.
  checkedConfig = pkgs.runCommand "noctalia-config-checked.toml" {} ''
    log=$(${lib.getExe noctaliaPkg} config validate ${rawConfig} 2>&1) \
      || { printf '%s\n' "$log" >&2; exit 1; }
    printf '%s\n' "$log"
    if printf '%s\n' "$log" | grep -q 'WARN'; then
      echo "noctalia: config validate emitted warnings; treating them as errors" >&2
      exit 1
    fi
    cp ${rawConfig} $out
  '';
in {
  programs.noctalia = {
    package = noctaliaPkg;
    checkConfig = false;      # superseded by checkedConfig above
    settings = checkedConfig;
    # ...
  };
}
```

### 7. (medium) Delete the dead variables.nix inherit, the stale 0.55.x comment, and the now-unused lib/host args

**File:** `modules/home-manager/windowManager/hyprland/default.nix`

**Rationale:** Confirmed on all three counts. (a) `host` is genuinely not available: flake/modules/home.nix passes extraSpecialArgs = { inherit inputs vars systems; outputs = projectOutputs; } and nothing anywhere sets _module.args.host. It evaluates only because the module system builds function args with a lazy builtins.mapAttrs and `inherit (expr) ;` with an empty list never forces `expr`. Add one name to that inherit and the whole flake stops evaluating. The path is doubly dead: relative to this file, ../hosts/ resolves to modules/home-manager/windowManager/hosts/, which has never existed. (b) `nix eval .#homeConfigurations."deadmade@deadPc".config.wayland.windowManager.hyprland.package.version` returns 0.56.2, not 0.55.x. (c) With the inherit gone, `lib` and `with lib;` have no remaining consumer — the body uses only imports/home.packages/home.file/services/wayland.*. (d) I've also dropped `services.network-manager-applet.enable` here; see the tray item.

**Verified against:** flake/modules/home.nix:13-16 (extraSpecialArgs); `grep -rn "_module.args" --include="*.nix"` (only constants.nix and exports.nix, neither defines host); `nix eval .#homeConfigurations."deadmade@deadPc".config.wayland.windowManager.hyprland.package.version` => 0.56.2

**Risk:** None. Removing hyprshot/wofi-emoji from home.packages is a separate item below; if you apply this snippet before that one you also drop them, so apply both together.

```nix
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./config.nix
    ./noctalia.nix
  ];

  home.packages = with pkgs; [
    # nm-connection-editor only -- the nm-applet tray icon duplicates
    # Noctalia's network widget and is no longer autostarted (see below).
    networkmanagerapplet
  ];

  # hyprsplit Lua library (require("hyprsplit") in config.nix). Hyprland adds
  # ~/.config/hypr to the Lua package.path, so this resolves at runtime.
  home.file.".config/hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";

  wayland.windowManager.hyprland = {
    package = pkgs.unstable.hyprland; # 0.56.2 -- required for configType = "lua"
    enable = true;
    configType = "lua"; # generate hyprland.lua instead of hyprland.conf
    xwayland.enable = true;
    systemd.enable = true;
  };
}
```

### 8. (low) stylix.targets.hyprlock.enable = false is valid and harmless — remove it as noise, not as a hazard

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Correcting the brief: this is NOT an eval error waiting to happen. Stylix release-26.05 still ships modules/hyprlock/{hm.nix,meta.nix}, its mkTarget generates the option unconditionally, and `nix eval …config.stylix.targets.hyprlock.enable` returns false cleanly. The repo's own hyprlock.nix module was deleted in 1f29958 and programs.hyprlock is not enabled, so the target's config would be inert either way. It is pure noise, so delete it — but delete it for tidiness, not out of fear. The starship line stays for now and is revisited in the starship item below; its comment is already wrong (the toml's palettes are half-migrated, not authoritative).

**Verified against:** .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/hyprlock/hm.nix and meta.nix exist; `nix eval` of config.stylix.targets.hyprlock.enable => false

**Risk:** None.

```nix
    targets = {
      # hyprlock.enable was removed: the repo's hyprlock module was deleted in
      # 1f29958 and locking is Noctalia's job now, so the target is inert.
      # Stylix's hyprlock target still exists upstream -- the line was valid,
      # just pointless.
      starship.enable = false; # revisited once Noctalia owns the prompt palette
      librewolf.profileNames = ["Default"];
    };
```

### 9. (low) deadConvertible's wpaperd block is dead — enable is never set

**File:** `hosts/deadConvertible/home.nix`

**Rationale:** Confirmed by eval: config.services.wpaperd.enable is false on deadConvertible, so the whole `settings` attrset renders a config file for a daemon that is never started. It is also conceptually dead now: Noctalia owns wallpaper on both hosts (programs.noctalia.settings.wallpaper.directory), so wpaperd has nothing left to do even if it were switched on. Note this leaves `config` unused in the deadConvertible module header once removed.

**Verified against:** `nix eval` of homeConfigurations."deadmade@deadConvertible".config.services.wpaperd.enable => false

**Risk:** None. Noctalia's wallpaper daemon already covers eDP-1 via the shared noctalia.nix.

```nix
# delete outright:
#   services.wpaperd = {
#     settings = {
#       eDP-1 = {
#         path = "${config.xdg.configHome}/wallpapers";
#         apply-shadow = true;
#       };
#     };
#   };
#
# ...and drop `config` from the module arguments, which then has no consumer:
{
  outputs,
  pkgs,
  ...
}: {
```

### 10. (medium) gtk.enable is redundant today but becomes load-bearing — move it into a module for both hosts

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Two findings here. First, the brief is right that it is redundant *today*: stylix's gtk target does `gtk.enable = true;` unconditionally (modules/gtk/hm.nix:33), and eval confirms gtk.enable is already true on BOTH hosts — including deadConvertible, which never sets it. So the bare block in hosts/deadPc/home.nix is a no-op and the two hosts are already effectively symmetric. Second, and more important: under the agreed colour plan this flips. Noctalia's gtk template rewrites ~/.config/gtk-{3,4}.0/gtk.css in place, which forces stylix.targets.gtk.enable = false (otherwise the template rm's HM's symlink and the next `nhs` aborts on an unmanaged file). The moment that target is off, nothing sets gtk.enable any more and HM stops writing settings.ini entirely — no font, no theme name, no gtk.css for Noctalia to @import into. So the line must survive, in a module, with the font carried over from Stylix's own values.

**Verified against:** .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/gtk/hm.nix:33 (`gtk.enable = true;`) and :35-39 (gtk.font from stylix fonts); `nix eval` => pcGtkEnable = true, cvGtkEnable = true; assets/templates/gtk/apply.sh ensure_gtk_css_import

**Risk:** stylix.nix currently takes only { pkgs, inputs, ... } and will need `config` added. If the colour domain decides to keep stylix.targets.gtk on and NOT use Noctalia's gtk template, this reverts to a plain `gtk.enable = true;` (or nothing at all).

```nix
# in modules/home-manager/core/stylix.nix, alongside the stylix block
# (applies to both desktop hosts; delete the bare `gtk = { enable = true; };`
#  from hosts/deadPc/home.nix)

# Stylix's gtk target normally sets gtk.enable itself, but that target has to
# be off: Noctalia's gtk3/gtk4 templates rewrite ~/.config/gtk-{3,4}.0/gtk.css
# in place, and their apply.sh deletes a read-only /nix/store symlink to do it,
# which breaks the next `home-manager switch`. Keep HM's gtk module on so
# settings.ini and gtk.css still exist for Noctalia to write into.
gtk = {
  enable = true;
  font = {
    inherit (config.stylix.fonts.sansSerif) package name;
    size = config.stylix.fonts.sizes.applications;
  };
};
```

### 11. (medium) Link ~/.face from the committed avatar and enable accounts-daemon

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Confirmed: ~/.face does not exist, shell.avatar_path points at it, and modules/home-manager/assets/avatar.jpg is present (15k, used by fastfetch). One home.file line fixes the lock screen and control-center avatar on both hosts. On accountsservice, the Noctalia docs settle it and raise the stakes: "When AccountsService is available, Noctalia also writes the selected avatar to org.freedesktop.Accounts as your user's IconFile. That is what Noctalia Greeter reads for the login user list." Since the agreed appetite includes swapping tuigreet for the Noctalia greeter, services.accounts-daemon.enable = true stops being cosmetic and becomes a prerequisite for the greeter showing a face. Eval confirms it is currently false and the option exists in 26.05. It belongs in modules/nixos/desktop/base.nix so both desktop hosts get it — but note deadConvertible does not import base today (see the drift item), so until that is fixed it needs the line directly.

**Verified against:** `ls ~/.face` => ENOENT; `ls modules/home-manager/assets/` => avatar.jpg; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/control-center/index.mdx:79; `nix eval` => options.services ? accounts-daemon = true, services.accounts-daemon.enable = false

**Risk:** accounts-daemon is a small extra system service and D-Bus surface. .face is a JPEG rather than PNG; Qt and AccountsService both accept it, but if the greeter is picky, re-encode the asset.

```nix
# modules/home-manager/windowManager/hyprland/noctalia.nix
  # shell.avatar_path points at ~/.face; ship the committed avatar there so the
  # lock screen, control centre, and (via AccountsService) the greeter user
  # list all have a face.
  home.file.".face".source = ../../assets/avatar.jpg;

  # ...and inside settings.shell, prefer the HM-derived home dir over vars:
  #   avatar_path = "${config.home.homeDirectory}/.face";

# modules/nixos/desktop/base.nix
  # Noctalia mirrors the selected avatar to org.freedesktop.Accounts IconFile,
  # which is what Noctalia Greeter reads for the login user list. Without this
  # the shell logs: accounts service disabled: org.freedesktop.DBus.Error.ServiceUnknown
  services.accounts-daemon.enable = true;
```

### 12. (medium) starship.toml: gut the broken palette and hand the prompt colours to Noctalia

**File:** `modules/home-manager/terminal/starship/default.nix`

**Rationale:** Every defect in the brief is real (verified in the toml): `purple` is referenced in format/[time]/vimcmd_replace_* but defined in no active palette; [docker_context] carries gruvbox's `#83a598` and `color_bg3`; `orange = "#cba6f7"` is mauve; `fg:creen` in vimcmd_symbol; [palettes.gruvbox_dark] is unreachable. But the decisive finding is that you cannot simply enable Noctalia's starship template on top of it. assets/templates/starship/apply.sh renders the palette to $XDG_CACHE_HOME and then edits the LIVE starship.toml in place -- `cat "$tmp_file" >"$config_file"`. Here $config_file resolves to /home/deadmade/.config/starship.toml (the script recovers STARSHIP_CONFIG by scanning /proc; HM sets it via home.sessionVariables at starship.nix:139), and that path is a /nix/store symlink. The write returns EACCES and `set -euo pipefail` kills the hook. The escape is HM's own `hasGeneratedConfig = cfg.settings != {} || cfg.presets != []` guard: with settings emptied, HM never writes the file, the path is free, and Noctalia's marker-block injection works -- it preserves whatever body it finds. So we seed the body from Nix at activation and let Noctalia own the palette block. Note apply.sh re-appends its block on every theme/wallpaper change, so a re-seed self-heals within one rotation.

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/assets/templates/starship/apply.sh (discover_starship_config + `cat "$tmp_file" >"$config_file"`) and assets/templates/builtin.toml:203-207; /nix/store/78alwxxdax9a1516a7rfr84i92ik43cl-home-manager-source/modules/programs/starship.nix:19 (hasGeneratedConfig) and :139 (sessionVariables.STARSHIP_CONFIG); `ls -la ~/.config/starship.toml` => store symlink; `env | grep STARSHIP` => STARSHIP_CONFIG=/home/deadmade/.config/starship.toml

**Risk:** This is the one file that stops being a store symlink -- it becomes a real, mutable file re-seeded on each activation. Between the seed and Noctalia's next template run the prompt has no palette (starship falls back to terminal defaults; it does not error). starship.toml itself still needs its four content bugs fixed by hand: drop [palettes.*] and `palette =`, replace `#83a598`/`color_bg3` in [docker_context] with `text`/`mantle`, rename `orange` usages to `mauve`, and fix `fg:creen` -> `fg:green`.

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Palette-free prompt body. Every hardcoded [palettes.*] table and the
  # `palette =` line are GONE: Noctalia's starship template generates
  # [palettes.noctalia] from the wallpaper and injects it between its markers.
  # Style strings keep the Catppuccin-compatible names the template emits
  # (base, mantle, surface0, peach, teal, green, blue, mauve, lavender, text).
  promptBody = (pkgs.formats.toml {}).generate "starship-body.toml"
    (lib.importTOML ./starship.toml);
in {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # MUST stay empty. HM only writes ~/.config/starship.toml when settings or
    # presets are non-empty; Noctalia's starship apply.sh rewrites that exact
    # path in place and gets EACCES on a /nix/store symlink.
    settings = {};
  };

  home.activation.starshipPrompt =
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.coreutils}/bin/install -Dm644 \
        ${promptBody} "${config.xdg.configHome}/starship.toml"
    '';
}
```

### 13. (medium) Delete the three hand-installed Noctalia plugins — they are v4 QML and v5 cannot load them

**File:** `docs (manual checklist)`

**Rationale:** More conclusive than the brief. The three dirs under ~/.config/noctalia/plugins/ each contain Main.qml, BarWidget.qml, Panel.qml and manifest.json — that is the v4 quickshell plugin shape. v5 plugins are "a directory containing a static plugin.toml manifest and one or more .luau entry scripts" running in Luau VMs; `find` for plugin.toml across both dirs returns nothing. Their manifests declare minNoctaliaVersion 3.6.0 (news) and 4.4.3 (ip-monitor). And they are in the wrong place regardless: v5's local-plugin path is ~/.local/share/noctalia/plugins/ (which does not exist here). So they are triply dead. On the declarative question: nix/home-module.nix exposes only enable/systemd/package/checkConfig/settings/customPalettes — no plugin option — but plugins ARE declarable through settings, because [plugins].enabled and [[plugins.source]] with kind = "path" are ordinary config keys, and the docs call a path source "Ideal for local development or Nix-managed plugins." So if you later want plugins, pin them via a store path source rather than by hand. Meanwhile auto_update defaults to "all", meaning background git fetches on startup and every 6 hours on a Nix box — set it to "none".

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/plugins/index.mdx (Luau + plugin.toml, [[plugins.source]] kind=path, auto_update enum); nix/home-module.nix (full option surface, no plugin option); `head -5 ~/.config/noctalia/plugins/*/manifest.json` (minNoctaliaVersion 3.6.0 / 4.4.3); `find … -name plugin.toml` => empty; ~/.local/share/noctalia/plugins does not exist

**Risk:** None to the running shell — they are already inert. Confirm with `noctalia msg plugins list` before deleting if you want belt-and-braces (I did not run it: it talks to the live shell).

```nix
# modules/home-manager/windowManager/hyprland/noctalia.nix, inside `settings`
      # No plugins are declared. auto_update defaults to "all", which git-fetches
      # the official and community sources on startup and every 6 hours -- not
      # something a declarative system should be doing behind your back.
      plugins = {
        enabled = [];
        auto_update = "none"; # "all" | "official" | "none"
      };

# manual, one-time (v4 QML plugins; v5 wants plugin.toml + .luau, and looks in
# ~/.local/share/noctalia/plugins/ anyway):
#   rm -rf ~/.config/noctalia/plugins
#
# if you ever want one back, declare it instead of copying it in:
#   [[plugins.source]]
#   name = "nix"; kind = "path"; location = "/nix/store/...-my-plugins"; enabled = true
#   [plugins] enabled = ["author/plugin"]
```

### 14. (medium) Stop autostarting nm-applet; keep solaar; blueman is NOT a duplicate (exploration was wrong)

**File:** `modules/home-manager/windowManager/hyprland/default.nix`

**Rationale:** I checked what is actually in the tray rather than what is configured. Running: nm-applet (pid 4474, network-manager-applet.service) and solaar (pid 4472, solaar.service). NOT running: any blueman process — `systemctl --user list-unit-files | grep blueman` shows blueman-applet.service as `linked-runtime ignored`. So services.blueman.enable is only providing the blueman-mechanism polkit backend and the blueman-manager GUI; it puts nothing in the tray and should be LEFT ALONE. That leaves exactly one true duplicate: nm-applet, whose tray icon sits next to Noctalia's own `network` widget. Drop the service, keep the package — Noctalia's own FAQ tells users to open nm-connection-editor for advanced network config, and that binary ships in networkmanagerapplet. Solaar is not a duplicate either: nothing in Noctalia reports MX Master 3S battery or Logitech device config, and `window = "hide"` means its tray icon is its only UI. Keep it. If it ever bothers you visually, Noctalia's tray widget has a `hidden` array keyed by id/name/bus token.

**Verified against:** `pgrep -a nm-applet` => pid 4474; `pgrep -a solaar` => pid 4472; `pgrep -af blueman` => no match; `systemctl --user list-unit-files | grep blueman` => blueman-applet.service linked-runtime ignored; `systemctl --user list-units --state=running`; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/bar/widgets/tray.mdx (hidden array), docs/user/getting-started/faq.mdx:406

**Risk:** You lose nm-applet's passive VPN/connection notifications. Noctalia's network widget covers status and the wifi panel; nm-connection-editor covers the rest.

```nix
# modules/home-manager/windowManager/hyprland/default.nix
  # nm-applet's tray icon duplicates Noctalia's `network` bar widget. The
  # package stays for nm-connection-editor (Noctalia's own FAQ points at it);
  # only the autostarted applet goes.
  # services.network-manager-applet.enable = true;   <- delete this line

# LEAVE AS-IS:
#   modules/nixos/desktop/bluetooth.nix  services.blueman.enable = true
#     -> blueman-applet.service is `linked-runtime ignored` and is not running;
#        this only provides blueman-mechanism + blueman-manager. Not a duplicate.
#   modules/nixos/desktop/logitech.nix   services.solaar.enable = true
#     -> Noctalia has no Logitech battery/config widget. Not a duplicate.
#
# optional, if you want solaar out of the bar without losing the daemon:
#   [widget.tray] hidden = ["solaar"]
```

### 15. (medium) Drop hyprshot and wofi-emoji for Noctalia's built-ins (screenshot IPC verified as a full replacement)

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** I checked the replacement before recommending removal, as asked. Noctalia's screenshot IPC covers every hyprshot capability and more: screenshot-region (interactive drag select), screenshot-fullscreen (focused monitor), screenshot-fullscreen pick / <output> / all, and screenshot-annotate (freezes every monitor and opens the annotation editor). Clipboard, save-to-file, freeze and pipe behaviour come from [shell.screenshot]; close_on_copy already defaults to true. It needs wlr-screencopy-unstable-v1, which Hyprland provides. For emoji, panel-toggle takes an optional pre-fill query — `noctalia msg panel-toggle launcher "/emo"` lands directly on the emoji provider, which example.toml:94 confirms is enabled by default at prefix "emo" under provider_prefix "/". That is an exact, themed replacement for wofi-emoji, which is currently unthemed anyway (programs.wofi is never enabled anywhere in the repo, so Stylix's wofi target never fires). One caveat worth knowing: hyprshot's wrapper is the only thing pulling hyprpicker in, and `which hyprpicker` already returns not found because it lives only inside that wrapper's PATH. So removing hyprshot loses nothing you can currently invoke — but if you want a colour picker, add pkgs.hyprpicker explicitly.

**Verified against:** .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/ipc/media-and-ui.mdx:113-133 (screenshot commands + freeze/annotate/clipboard), docs/user/ipc/surfaces.mdx:31 (panel-toggle launcher [query]), example.toml:94-95 and :43-44 ([shell.screenshot]); `which hyprpicker` => not found; `grep -rn wofi` shows no programs.wofi in the repo

**Risk:** Noctalia's region capture needs the shell running; if noctalia.service is down you have no screenshot at all, whereas hyprshot was independent. Also `noctalia msg panel-toggle launcher "/emo"` needs the single-quote form shown so the double quotes survive into the Lua string.

```nix
# modules/home-manager/windowManager/hyprland/config.nix
      -- Noctalia's screenshot subsystem: region select, freeze, annotate,
      -- clipboard and save all come from [shell.screenshot].
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
      hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"))
      hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen pick"))

      -- panel-toggle takes an optional pre-fill query; "/emo" is the built-in
      -- emoji provider (provider_prefix "/" + prefix "emo").
      hl.bind(mainMod .. " + X", hl.dsp.exec_cmd('noctalia msg panel-toggle launcher "/emo"'))

# modules/home-manager/windowManager/hyprland/default.nix
  home.packages = with pkgs; [
    networkmanagerapplet  # nm-connection-editor
    # hyprshot   -> replaced by `noctalia msg screenshot-*`
    # wofi-emoji -> replaced by the launcher's /emo provider (and it was
    #               never themed: programs.wofi is not enabled anywhere,
    #               so Stylix's wofi target never fired)
    hyprpicker  # was only reachable inside hyprshot's wrapper PATH
  ];
```

### 16. (medium) deadConvertible's hand-rolled portals and pipewire are drift, not a deliberate divergence

**File:** `hosts/deadConvertible/config.nix`

**Rationale:** Assessed as drift. deadConvertible imports desktop.bluetooth/packages/stylix/vpn/ai/jetbrains/tailscale/wayvnc individually — i.e. every desktop module EXCEPT base — and then re-implements exactly what base provides: the same two extraPortals, the same pipewire block, and the same environment.pathsToLink. Nothing in it is laptop-specific. The `common.default = "hyprland"` string vs base's `["hyprland" "gtk"]` list is the tell: both are accepted by the option type, but the string form drops the gtk fallback, so any portal interface xdg-desktop-portal-hyprland does not implement (file chooser, settings, print) has no backend on the laptop and does on the desktop. That is a behavioural difference nobody chose. Note deadPc reaches base via nixosProfiles.desktopAll, so the fix is just to add base to the import list.

**Verified against:** hosts/deadConvertible/config.nix (imports list, lines 29/45-56/61-73) vs profiles/nixos/desktop-all.nix and modules/nixos/desktop/base.nix; hosts/hosts.nix; hosts/deadPc/config.nix imports outputs.nixosProfiles.desktopAll

**Risk:** deadConvertible picks up alsa.support32Bit = true (a few MB of 32-bit ALSA plugins on a laptop) and gains the gtk portal fallback. Both are improvements, but this changes portal behaviour on that host, so rebuild it before you rely on file-chooser dialogs there.

```nix
  imports =
    [
      ./hardware-configuration.nix

      inputs.hardware.nixosModules.common-cpu-amd
      inputs.hardware.nixosModules.common-gpu-amd
      inputs.hardware.nixosModules.common-pc-laptop
      inputs.hardware.nixosModules.common-pc-ssd

      outputs.nixosModules.desktop.base      # <- was missing; supplies portals,
                                             #    pipewire and pathsToLink
      outputs.nixosModules.desktop.bluetooth
      outputs.nixosModules.desktop.packages
      # ... rest unchanged
    ]
    ++ (builtins.attrValues outputs.nixosModules.core);

# then DELETE from this file (all three are now provided by base.nix):
#   environment.pathsToLink = ["/share/zsh"];
#   xdg.portal = { ... };                       # base uses ["hyprland" "gtk"]
#   services.pulseaudio.enable / security.rtkit.enable / services.pipewire = { ... }
#
# NOTE: base sets alsa.support32Bit = true while this host sets false. You must
# delete the local pipewire block entirely -- leaving it produces a
# "conflicting definition values" eval error, not a silent override.
```

### 17. (medium) Reconcile vars: delete the four unused keys, or make the Hyprland config consume them

**File:** `flake/modules/constants.nix`

**Rationale:** I traced every consumer before proposing removal. Across the whole repo (excluding .direnv), vars is referenced in exactly six places: vars.username in modules/nixos/core/user.nix (x3), hosts/deadWsl/config.nix, and noctalia.nix (x2); vars.gitUsername/gitEmail in modules/home-manager/core/git.nix; and vars.username in flake/modules/home.nix for the homeConfigurations attr name. That is all. vars.terminal ("kitty"), vars.browser ("helium"), vars.keyboardLayout ("de") and vars.consoleKeyMap ("de") have ZERO consumers, and README.md never mentions vars. Meanwhile the values are actively wrong: config.nix hardcodes terminal = "ghostty" (kitty is explicitly disabled via programs.kitty.enable = false), launches librewolf on start and on SUPER+W (not helium), and localization.nix hardcodes console.keyMap = "de" / xkb.layout = "de". Wiring them up is the wrong call here — vars is a NixOS specialArg, and threading it into a Lua string just to say "ghostty" adds a hop for no benefit. Delete them, and separately fix the third bug in the same block: fileManager is "thunar", which is not installed anywhere; nautilus is (modules/nixos/desktop/packages.nix:22) and is currently unbound, so SUPER+E does nothing.

**Verified against:** `grep -rn "vars\." --include="*.nix"` over the repo (6 hits, all username/gitUsername/gitEmail); `grep -rn "keyboardLayout|consoleKeyMap|vars.terminal|vars.browser"` => only constants.nix itself; `grep -n "vars|constants" README.md` => no output; modules/nixos/core/localization.nix; modules/nixos/desktop/packages.nix:22 (nautilus); modules/home-manager/terminal/kitty/default.nix (enable = false)

**Risk:** None mechanical — nothing reads them. If you'd rather keep vars as documentation of intent, fix the values instead of deleting (terminal = "ghostty", browser = "librewolf") so they stop lying.

```nix
# flake/modules/constants.nix -- keep only what is actually consumed
    vars = {
      gitUsername = "deadmade";   # modules/home-manager/core/git.nix
      gitEmail = "manuel.schuelein@proton.me";
      username = "deadmade";      # nixos/core/user.nix, deadWsl, home.nix, noctalia.nix
      # Removed -- no consumer anywhere in the repo, and all four disagreed
      # with the config that actually runs:
      #   browser = "helium";        (config.nix launches librewolf)
      #   terminal = "kitty";        (config.nix uses ghostty; kitty is disabled)
      #   keyboardLayout = "de";     (nixos/core/localization.nix hardcodes it)
      #   consoleKeyMap = "de";      (same)
    };

# modules/home-manager/windowManager/hyprland/config.nix -- while you are here:
      terminal._var = "ghostty";
      fileManager._var = "nautilus";  # was "thunar", which is not installed;
                                      # nautilus is (nixos/desktop/packages.nix)
```

### 18. (medium) Enable launch_apps_as_systemd_services — every `nhs` currently kills apps launched from the launcher

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Not in the brief, but it is a real correctness defect and squarely in this domain. `noctalia config export full` shows shell.launch_apps_as_systemd_services = false. With programs.noctalia.systemd.enable = true (which this config sets), apps launched from the Noctalia launcher are children of noctalia.service. The HM module gives that unit X-Restart-Triggers on config.toml and every palette file, so a `nhs` that touches either restarts the unit — and takes your launcher-started apps with it. Noctalia's own NixOS doc says exactly this: "When using the service, it is recommended to enable launch_apps_as_systemd_services, otherwise any apps launched by Noctalia will be terminated when the service restarts." With the colour plan making the palette regenerate on every wallpaper rotation, this gets worse, not better. Bundled with it: polkit_agent = false while security.polkit.enable is on and no agent package is installed anywhere in the repo — so any polkit prompt today silently fails. Noctalia ships one for free.

**Verified against:** `noctalia config export full` lines 439 and 444; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/docs/user/getting-started/nixos.mdx (Systemd Service section); nix/home-module.nix (X-Restart-Triggers on config.toml + every customPalettes file); src/config/schema/config_schema.cpp:1575; `grep -rn polkit` over the repo => only security.polkit.enable in modules/nixos/core/security.nix

**Risk:** launch_apps_as_systemd_services is mutually exclusive with launch_apps_custom_command (the shell logs and ignores the custom command); neither is set here. Noctalia's polkit agent only runs while the shell does — if noctalia.service dies you are back to no agent.

```nix
      shell = {
        avatar_path = "${config.home.homeDirectory}/.face";

        # programs.noctalia.systemd.enable makes launcher-started apps children
        # of noctalia.service, and the unit's X-Restart-Triggers restart it on
        # every config/palette change -- i.e. every `nhs` kills your apps.
        # Scoping them as transient units detaches them. Recommended by
        # docs/user/getting-started/nixos.mdx whenever the service is used.
        launch_apps_as_systemd_services = true;

        # security.polkit.enable is on but nothing in this repo installs an
        # agent, so privilege prompts currently go nowhere. Noctalia has one.
        polkit_agent = true;

        panel = { /* … */ };
      };
```

### 19. (low) Manual checklist: unmanaged files on disk that will mislead future debugging

**File:** `docs (manual checklist)`

**Rationale:** All verified present. ~/.config/hypr/hyprland.conf is Hyprland's fallback stub — its first line is literally "# This config is a STUB! This should never be generated." and it binds $terminal=kitty, $fileManager=dolphin, $menu=hyprlauncher, none of which are installed. It was written 20 Jun, the day of the Lua migration, when Hyprland briefly found no config. It is inert now (hyprland.lua wins) but it is exactly the file someone greps first when a keybind misbehaves. hyprland.conf.backup (6 Mär, 4.9k) is a pre-migration hyprlang config. ~/.config/hypr/noctalia/noctalia-colors.conf is a v4 orphan holding rgb(fff59b)/rgb(070722) — a palette from a wallpaper you no longer use — and v5 writes ~/.config/hypr/noctalia.lua instead, one level up. ~/.config/noctalia/colorschemes/ is an empty v4 directory. Two things NOT on this list on purpose: ~/.config/hypr/hyprpaper.conf is an HM symlink that disappears on its own once stylix.targets.hyprland.hyprpaper.enable = false, and ~/.local/state/noctalia/community-{palettes,templates}/ are legitimate re-fetchable caches.

**Verified against:** `ls -la ~/.config/hypr/` and `~/.config/noctalia/`; `head -20 ~/.config/hypr/hyprland.conf` (STUB banner); `cat ~/.config/hypr/noctalia/noctalia-colors.conf`; .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/assets/templates/hyprland/apply.sh (lua_output_file = $config_dir/noctalia.lua)

**Risk:** hyprland.conf.backup may be the only copy of your pre-migration hyprlang config — `git show 1f29958^:modules/home-manager/windowManager/hyprland/config.nix` has the tracked version, but if the backup has untracked local edits, read it before deleting.

```nix
# Run these by hand; none of them are Nix-managed.

# Hyprland's fallback stub, generated 20 Jun when the Lua migration briefly
# left it with no config. Inert (hyprland.lua wins) but it binds kitty/dolphin/
# hyprlauncher and is the first thing you'll grep when a keybind misbehaves.
rm ~/.config/hypr/hyprland.conf

# pre-migration hyprlang config, superseded by hyprland.lua
rm ~/.config/hypr/hyprland.conf.backup

# Noctalia v4 colour orphan. v5's hyprland template writes
# ~/.config/hypr/noctalia.lua one level up instead.
rm -rf ~/.config/hypr/noctalia

# empty v4 directory
rmdir ~/.config/noctalia/colorschemes

# v4 QML plugins -- see the plugin item
rm -rf ~/.config/noctalia/plugins

# DO NOT delete:
#   ~/.config/hypr/hyprpaper.conf   -- HM symlink; goes away by itself once
#                                      stylix.targets.hyprland.hyprpaper.enable = false
#   ~/.local/state/noctalia/community-*  -- re-fetchable caches
#   ~/.local/state/noctalia/settings.toml -- edit surgically, don't delete
#                                            (holds live wallpaper state)
```

## Open questions

1) Item 8 (starship) has no clean answer that is both declarative and wallpaper-coloured — starship has no `include` mechanism, so Noctalia's only hand-off is in-place marker-block injection into `~/.config/starship.toml`. I propose the seeded-mutable-file route, but it makes that one file imperative. If you'd rather keep it fully declarative, drop the noctalia `starship` template and accept a static prompt palette; say which and I'll cut the other. 2) Whether Hyprland auto-reloads on `~/.config/hypr/noctalia.lua` changing is unverified — Hyprland watches the main config, and I could not confirm it watches `require`d Lua modules. If it doesn't, wallpaper-driven border colours will lag until the next `hyprctl reload`; a `[hooks]` entry calling `hyprctl reload` would cover it but I did not want to guess at the hook key name. 3) Item 1c has no exact v5 equivalent: v4's `calendar.cards` let you hide the calendar in the clock popup; v5 only exposes `show_events_card`/`show_week_numbers`. The nearest full removal is `[widget.clock] interactive = false`, which also kills the tooltip. I've proposed the former; tell me if you actually want the popup gone. 4) I have NOT run `noctalia msg plugins …` (read-only session), so the plugin-source recommendation is from source + docs + on-disk manifests only.
