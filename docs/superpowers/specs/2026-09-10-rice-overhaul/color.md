# Colour architecture

_Colour architecture — migrating colour authority from Stylix to Noctalia (deadPc / deadConvertible)_

Noctalia becomes the palette authority via `theme.source = "wallpaper"` with `wallpaper_scheme = "m3-content"`, and Stylix is reduced to fonts + cursor + the handful of apps Noctalia cannot template (librewolf, fontconfig, gnome dconf font/cursor keys). The single hardest constraint, which I verified rather than assumed, is that every Noctalia builtin template ships an `apply.sh` that *edits the target app's own config file in place* — and under Home Manager those files are read-only /nix/store symlinks. The migration therefore has two halves: turn the colliding Stylix targets off so the file stops existing (gtk.css), or pre-write the exact line the apply script is looking for so it takes its no-op branch (`theme = noctalia` for ghostty, `color_theme = "noctalia"` for btop, `require("noctalia")` for hyprland.lua). I evaluated the complete proposed change set against `homeConfigurations."deadmade@deadPc"` and `nixosConfigurations.deadPc`: it builds with zero warnings, and along the way the evaluator caught two real conflicts (a dconf `font-name` clash with `stylix.targets.gnome`, and `gtk.gtk4.theme` still emitting a gtk.css that Noctalia would have deleted out from under Home Manager) which the snippets below already fix.

## Fatal problems flagged by the verifier

Nothing here breaks `nix flake check` or aborts evaluation on the evidence I could gather, but three items will break the running session and one is under-verified:

1. RUNTIME BREAKAGE — bat. `programs.bat.config.theme = "noctalia"` (change 5) makes every `bat` invocation fail with `unknown theme 'noctalia'` between the switch and the first Noctalia render, because home-manager only runs `bat cache --build` at activation (home-manager modules/programs/bat.nix:209-217) and the community bat apply.sh payload is not cached so its cache-rebuild behaviour is unproven. bat is this shell's pager. Drop `"bat"` from community_ids and keep `stylix.targets.bat.enable = true` in pass one.

2. ACTIVATION ABORT — qt6ct. `~/.config/qt6ct/qt6ct.conf` exists on disk today as a plain 207-byte file. `xdg.configFile."qt6ct/qt6ct.conf"` (change 7) will abort the first `nhs` with "would be clobbered". `rm ~/.config/qt6ct/qt6ct.conf` before switching. Same class, lower probability: ~/.config/gtk-3.0/gtk.css and gtk-4.0/gtk.css must be plain-file-free at the moment Noctalia's gtk apply.sh first runs — that script deliberately `rm`s a read-only symlink (assets/templates/gtk/apply.sh, ensure_gtk_css_import), so the ORDER in change 2 is mandatory, not advisory: disable stylix.targets.gtk and switch BEFORE enabling the gtk3/gtk4 templates.

3. SILENT REGRESSION — fzf and fastfetch. Both templates write a file nothing reads (no post_hook, no include). Disabling stylix.targets.fzf therefore takes fzf from Catppuccin to unthemed. See the fzf verdict for the fix.

4. UNDER-VERIFIED, could hard-fail evaluation — the dconf co-definition. stylix.targets.gnome (enabled: autoEnable = isLinux) and home-manager's gtk3 module both define `dconf.settings."org/gnome/desktop/interface"."font-name"` and `."color-scheme"`. The design says an eval succeeded; I could not reproduce a build in this read-only session and did not read hm.types.gvariant's merge function. Deriving the value from config.stylix.fonts (as proposed) is the only shape that can possibly merge, so keep it — but expect the first build of change 3 to be the one that tells you.

One process note: `programs.noctalia.checkConfig` defaults to true and runs `noctalia config validate` on the generated TOML at build time (nix/home-module.nix:126-134), but validate only WARNS on unknown settings and unknown enum values — the three existing v4 leftovers prove it (live run: `launcher_placement: unknown value "centered"`, `calendar.cards: unknown setting`). So no Noctalia key or enum in this design will ever be caught by the build. Every one of them had to be checked against the source, which is what the verdicts above do.

## Verdicts

### [CONFIRMED] 1. Noctalia theme block: source="wallpaper", wallpaper_scheme="m3-content", mode="dark", delete customPalettes.stylix

**Evidence:** Every name and value checked against the C++ source, not just docs. src/config/config_types.h:1433 `{PaletteSource::Wallpaper, "wallpaper", ...}`; :1549 `std::string wallpaperScheme = "m3-content";`; :1551-1552 `shellMode = ShellThemeMode::Follow` / `pureBlackDark = false` (so both really are the defaults the design declines to restate). src/theme/scheme.h:30,36 and src/shell/wallpaper/panel/wallpaper_panel.cpp:95-96 give the full generator enum incl. `soft`. docs/user/theming/index.mdx:14-18 `source = builtin|wallpaper|community|custom`. src/theme/theme_service.cpp:406 `kLog.warn("unknown wallpaper scheme '{}', falling back to m3-content")` — corroborates the design's own risk note that a typo here is silent, never a build failure. Note example.toml:146-148 lists only NINE generators (omits `soft`); the design's "ten" is correct and example.toml is the stale source. Deleting customPalettes.stylix is safe: the HM module's only use is xdg.configFile "noctalia/palettes/<name>.json" plus an X-Restart-Triggers entry (nix/home-module.nix:104-107, :137-142). After deletion the `config` and `lib` args in noctalia.nix are unused, which is fine under `...`.

### [CONFIRMED] 2. Stylix demotion — the nine/twelve target names and stylix.image = null

**Evidence:** Target names all real. Directory-derived targets (stylix/autoload.nix walks ../modules/<target>/<platform>.nix): hyprland, gtk, ghostty, btop, bat, fzf, tmux, zed, hyprlock, starship all exist under stylix/modules/. There is NO `discord` target option — nixcord/vencord/vesktop are mkTarget names declared inside modules/discord/{nixcord,vencord,vesktop}.nix (nixcord.nix:10 `name = "nixcord";`), imported by modules/discord/hm.nix — so the design naming all three is exactly right. `librewolf` likewise is not a directory; it comes from modules/firefox/hm.nix:10 `"librewolf" = "LibreWolf";`. image=null is legal: stylix/palette.nix:30-33 `type = nullOr (coercedTo path ... pathInStore); default = null`, and :126 throws only when base16Scheme is ALSO unset. The gnome target's `picture-uri = "file://${image}"` (modules/gnome/hm.nix:33) is skipped rather than erroring because stylix/mk-target.nix:178-183 `areArgumentsEnabled` = `value.enable or (value != null) && ...` → false for a null image → mkIf false. hyprpaper: modules/hyprland/hm.nix declares `hyprpaper.enable` with `autoEnable = image != null` and its config block sets `services.hyprpaper.enable = true` — and ~/.config/hypr/hyprpaper.conf is a live HM store symlink, confirming it is on today. The gtk clobber hazard is real and verbatim: assets/templates/gtk/apply.sh, ensure_gtk_css_import → `# Read-only symlink (e.g. NixOS): convert to a local file` followed by `rm "$gtk_css"`.

### [WRONG] 2b. Disabling stylix.targets.fzf leaves fzf with NO theme (gap the design does not cover)

**Evidence:** ~/.local/state/noctalia/community-templates/fzf/template.toml declares only `[templates.fzf_bash] output_path = "$XDG_CONFIG_HOME/fzf/themes/noctalia.sh"` and `[templates.fzf_fish] ... noctalia.fish` — no post_hook, no apply.sh, nothing that touches a shell rc. modules/home-manager/terminal/zsh.nix:10-14 sets `programs.fzf.enable` with the comment "Colors are managed by Stylix", i.e. `programs.fzf.colors` comes only from stylix/modules/fzf/hm.nix. Turn that target off and FZF_DEFAULT_OPTS loses its colours while noctalia.sh is written and never read: a net regression, not a migration.

**Correction:**

Either keep `stylix.targets.fzf.enable = true` (fzf stays Catppuccin — an accepted casualty like starship), or source the generated file explicitly, e.g. in modules/home-manager/terminal/zsh.nix:

  programs.zsh.initContent = lib.mkAfter ''
    [ -r "''${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh" ] \
      && source "''${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh"
  '';

The .sh payload is NOT cached locally, so its variable name/format is unverified — read it after the first render before committing this.

### [CONFIRMED] 3. GTK re-plumb: gtk.colorScheme, adw-gtk3-dark, Papirus-Dark, gtk4.theme = null

**Evidence:** gtk.colorScheme exists at home-manager modules/misc/gtk.nix:77 with `types.enum ["dark" "light"]`; gtk3 inherits it (modules/misc/gtk/gtk3.nix:79-88 `default = cfg.colorScheme`) and writes the contested dconf keys at :148-167 (font-name, gtk-theme, icon-theme, cursor-theme, color-scheme). gtk4.theme legacy default confirmed: modules/misc/gtk/gtk4.nix uses `lib.hm.deprecations.mkStateVersionOptionDefault { since = "26.05"; legacy.value = cfg.theme; current.value = null; }` and modules/home-manager/core/homeConfig.nix:5 pins `home.stateVersion = "24.11"` → the legacy branch is live, so gtk-4.0/gtk.css really would still be written. Packages exist: `nix eval` on this flake's nixpkgs gives adw-gtk3-6.5 and papirus-icon-theme-20250501, and /nix/store/*-adw-gtk3-6.5/share/themes/ contains both `adw-gtk3` and `adw-gtk3-dark`. Noctalia's theme_exists() lookup will resolve: `systemctl --user show-environment` shows XDG_DATA_DIRS starting with /home/deadmade/.nix-profile/share, where standalone HM installs theme packages.

**Correction:**

Two placement nits, not correctness bugs: (a) hosts/deadPc/home.nix:47 ALREADY has `gtk = { enable = true; };` — two `true` definitions merge, but delete the host copy once the module owns gtk (deadConvertible has no gtk block at all, which is why the module is the right home). (b) A file named modules/home-manager/core/stylix.nix defining gtk + qt config is off-domain for this repo's layering. flake/lib/registry.nix auto-discovers any new .nix under modules/home-manager/core/, and CLAUDE.md says core is imported wholesale via `builtins.attrValues`, so split these into modules/home-manager/core/gtk.nix and .../qt.nix and leave stylix.nix holding only stylix.*.

### [UNCERTAIN] 3b. The dconf font-name / color-scheme co-definition is the one thing I could not prove merges

**Evidence:** stylix/modules/gnome/hm.nix:65-70 defines `dconf.settings."org/gnome/desktop/interface".font-name = "${fonts.sansSerif.name} ${fontSize}"` and :55-56 `.color-scheme = "prefer-dark"`; home-manager modules/misc/gtk/gtk3.nix:148-167 defines the SAME two keys. The gnome target is enabled here (modules/gnome/hm.nix:28 `autoEnable = pkgs.stdenv.hostPlatform.isLinux`). Whether two equal definitions of an `hm.types.gvariant` leaf merge or hard-conflict depends on that type's merge function, which I did not read; the design asserts an eval succeeded but I cannot reproduce a build in this read-only session.

**Correction:**

Keep the design's derivation (`inherit (config.stylix.fonts.sansSerif) package name; size = config.stylix.fonts.sizes.applications;`) — it is right either way, since equal values are the only shape that can possibly merge. But make the FIRST build of this change the one you watch for `The option 'dconf.settings."org/gnome/desktop/interface".font-name' has conflicting definition values`. If it errors, the fallback is `stylix.targets.gnome.enable = false;` plus keeping the gtk font block.

### [CONFIRMED] 4. Hyprland Lua handshake — the require("noctalia") literal and package.loaded bust

**Evidence:** assets/templates/hyprland/apply.sh, apply_lua(): `if ! grep -qF 'require("noctalia")' "$lua_config_file"; then printf '\n%s\n' "$include_line" >>"$lua_config_file"; fi` — a fixed-string check, under `set -euo pipefail`, appending to ~/.config/hypr/hyprland.lua. `ls -la ~/.config/hypr/` shows hyprland.lua is a symlink into /nix/store/...-home-manager-files/, so the append would EACCES and kill the hook exactly as described, and the grep-guard escape is exactly as described. assets/templates/hyprland/hyprland.lua ends with `return { colors = { primary, surface, on_surface, secondary, on_secondary, error, on_error }, apply_theme = apply_theme }` — the seven names the design lists, all as `"rgb(rrggbb)"` strings, verbatim. The design's insistence that `pcall(require, "noctalia")` would NOT satisfy the grep is correct: the literal `require("noctalia")` with parens and quotes is what -qF matches, and `pcall(function() return require("noctalia") end)` contains it. detect_mode probes `hyprctl dispatch 'hl.dsp.no_op()'` first and falls back to `[ -f hyprland.lua ]` — both routes land on lua here, so the stale writable ~/.config/hypr/hyprland.conf (541 bytes, 20 Jun) cannot hijack it.

### [UNCERTAIN] 4b/10b. hooks.colors_changed = ["hyprctl reload"] — the key is real, the choice of command is riskier than stated

**Evidence:** The hook key is real: src/config/config_types.h:1395 `{HookKind::ColorsChanged, "colors_changed", ""}`, and example.toml:487 shows the list form `colors_changed = []`, so `hooks.colors_changed = ["..."]` is a legal shape. The live startup log confirms `hooks kinds with commands=0` today. What the design under-analyses is the blast radius: `hyprctl reload` re-executes ALL of modules/home-manager/windowManager/hyprland/config.nix extraConfig every 30 minutes — that re-runs `require("hyprsplit")` + `hs.config({ num_workspaces = 10 })` and re-registers all 459 binds, not just the hl.on("hyprland.start") block the design checked. hyprsplit is a vendored third-party Lua library (home.file.".config/hypr/hyprsplit/init.lua" from inputs.hyprsplit); nothing establishes that its config() is idempotent under reload.

**Correction:**

Prefer a hook that re-applies only the palette, using the same Lua-dispatch channel apply.sh itself probes with `hyprctl dispatch 'hl.dsp.no_op()'`:

      hooks.colors_changed = [
        "hyprctl dispatch 'package.loaded[\"noctalia\"] = nil; require(\"noctalia\").apply_theme()'"
      ];

I verified the dispatch-Lua channel exists (apply.sh detect_mode) but NOT that it accepts two statements — test it live with `hyprctl dispatch 'hl.dsp.no_op()'` first, and fall back to `hyprctl reload` only if the multi-statement form is rejected. Keep the package.loaded bust in config.nix regardless; it is correct for both routes.

### [CONFIRMED] 5a. ghostty theme = "noctalia" and btop color_theme = "noctalia" pre-seed

**Evidence:** assets/templates/ghostty/apply.sh line 20: `if grep -qE '^theme\s*=\s*noctalia$' "$config_file"; then :` — an early no-op branch, then `bash "$script_dir/reload.sh"` unconditionally. Live ~/.config/ghostty/config renders `theme = stylix` UNQUOTED (checked with sed), so HM's rendering of `settings.theme = "noctalia"` produces `theme = noctalia` and matches the anchored regex exactly. assets/templates/btop/apply.sh: `if grep -qE '^color_theme\s*=\s*"noctalia"' "$config_file"; then :` … then `pkill -SIGUSR2 -x btop`. Live ~/.config/btop/btop.conf line 1 is `color_theme = "stylix"` — QUOTED, so HM's rendering matches that regex too. Both file references are right: modules/home-manager/terminal/ghostty.nix and modules/home-manager/core/btop.nix.

### [WRONG] 5b. programs.bat.config.theme = "noctalia" — this one breaks bat

**Evidence:** ~/.local/state/noctalia/community-templates/bat/template.toml writes `$XDG_CONFIG_HOME/bat/themes/noctalia.tmTheme` and calls an apply.sh whose payload is NOT cached (only template.toml is present), so the design's guess that it runs `bat cache --build` is unverified. Meanwhile home-manager modules/programs/bat.nix:209-217 puts `home.activation.batCache` (which runs `bat cache --build`) in the UNCONDITIONAL config block — it fires at HM activation only. So the ordering is: switch → bat/config now says `--theme=noctalia` → the theme file does not exist yet (Noctalia has not rendered) → the cache does not contain it → every `bat` invocation errors with `unknown theme 'noctalia'`. bat is a pager in this shell setup, so that is a visible breakage, not a cosmetic one. Even after it heals, the cache is only rebuilt on `nhs`, so bat keeps stale colours across every 30-minute rotation.

**Correction:**

Do not set it in the first pass. Keep `stylix.targets.bat.enable = true;` and drop `"bat"` from community_ids until you have read the fetched ~/.local/state/noctalia/community-templates/bat/apply.sh and confirmed it runs `bat cache --build`. If it does, then flip both together — and remember `programs.bat.config.theme` lives in modules/home-manager/terminal/zsh.nix:2 (correct file in the design), not in a bat.nix.

### [UNCERTAIN] 5c. zed theme = lib.mkForce "Noctalia" and nixcord enabledThemes

**Evidence:** zed community template.toml: `[templates.zed] input_path = "zed.json", output_path = "$XDG_CONFIG_HOME/zed/themes/noctalia.json"` — no post_hook, and the payload zed.json is not cached, so the string Zed will match is genuinely unknown; the design flags this itself. Two corrections around it: with stylix.targets.zed disabled there is no longer a competing definition (stylix/modules/zed/hm.nix sets `userSettings.theme = "Base16 ${colors.scheme-name}"` at normal priority), so the `lib.mkForce` at modules/home-manager/coding/zed.nix:42 becomes unnecessary — harmless, but it is now noise. For nixcord: discord/template.toml confirms the vesktop outputs (`noctalia.theme.css`, `noctalia-material.theme.css`, `discord-system24.css` under $XDG_CONFIG_HOME/vesktop/themes/), and stylix/modules/discord/nixcord.nix does pin `programs.nixcord.config.enabledThemes = ["stylix.theme.css"]` — so the design is right that stylix.targets.nixcord must go off first. modules/home-manager/socialMedia/vencord.nix has `enable = false; discord.enable = false; vesktop.enable = true;`, which is the branch that writes to vesktop/themes.

**Correction:**

Ship the zed line as `theme = "Noctalia";` (drop mkForce) and treat the exact name as a follow-up: after the first render run `jq -r 'if has("themes") then .themes[].name else .name end' ~/.config/zed/themes/noctalia.json` and correct modules/home-manager/coding/zed.nix to whatever it prints.

### [CONFIRMED] 6. Template roster: seven builtin_ids, eleven community_ids

**Evidence:** Builtins verified two ways: assets/templates/builtin.toml section headers at :123 [templates.gtk3], :132 [templates.gtk4], :144 [templates.kcolorscheme], :168 [templates.hyprland], :180 [templates.qt], :117 [templates.ghostty], :93 [templates.btop]; and live `noctalia theme --list-templates`, whose 21-row builtin table contains exactly those ids. Every one of the eleven community ids exists in the local catalogue: `ls ~/.local/state/noctalia/community-templates/` lists bat, claude-code, discord, fastfetch, fzf, heroiclauncher, obs, obsidian, tmux, vscode, zed (also steam and papirus-icons, correctly excluded). requires_path guards confirmed from the cached template.toml files: vscode has three entries guarded on ~/.vscode, ~/.vscode-oss, ~/.antigravity-ide; heroiclauncher on ~/.config/heroic; steam has NO guard, so excluding it is right. The qt justification is solid: stylix/modules/qt/hm.nix:13-16 really is `autoEnable = nixosConfig != null` with the TODO comment, and ~/.config/qt6ct/colors is empty on disk — the HM qt target has never run. kcolorscheme is justified by modules/nixos/desktop/packages.nix:12 `pkgs.unstable.kdePackages.okular`.

### [WRONG] 6b. "deadPc has no gaming profile" is factually false

**Evidence:** hosts/deadPc/home.nix:9 imports `outputs.homeManagerProfiles.desktopGaming`, and profiles/home-manager/desktop-gaming.nix imports `outputs.homeManagerModules.gaming`, which installs heroic, lutris, gamescope, gamemode. What deadPc lacks is the NIXOS gaming profile: hosts/deadPc/config.nix:120 says "programs.steam, which this host does not enable (no gaming profile)". The design uses the false claim as the stated reason to drop `steam` from community_ids while simultaneously keeping `heroiclauncher` "via the gaming profile" — internally contradictory.

**Correction:**

Both conclusions survive on the corrected reason. Keep `"heroiclauncher"` (heroic IS installed, via the HM gaming profile, and it is requires_path-guarded on ~/.config/heroic anyway). Keep `steam` excluded, but say why: modules/nixos/gaming/steam.nix is only reachable through profiles/nixos/gaming.nix, which deadPc does not import — and the steam template has no requires_path, so it would blindly create ~/.steam/steam/steamui/skins/Material-Theme/... for a launcher that is not installed.

### [WRONG] 6c. fastfetch and obs are listed as wins but have no delivery mechanism

**Evidence:** fastfetch/template.toml: `output_path = "$XDG_CONFIG_HOME/fastfetch/themes/noctalia.jsonc"` — no post_hook, no apply.sh. modules/home-manager/terminal/fastfetch.nix drives programs.fastfetch with a settings attrset, so ~/.config/fastfetch/config.jsonc is a read-only store symlink and nothing in it includes themes/noctalia.jsonc. Same shape as fzf: the file is written and never read. obs/template.toml: `output_path = '$XDG_CONFIG_HOME/obs-studio/themes/matugen.obt'`, also hookless — OBS will not switch to it on its own.

**Correction:**

Keep both ids if you like (they are inert and cost nothing), but do not count them as themed. obs needs a one-time manual pick in Settings → Appearance → Theme (the .obt then tracks the wallpaper). fastfetch needs the theme merged into its config, which HM owns — so it is the same class of problem as starship and wants the same fix (a `[theme.templates.user.*]` entry rendering the whole config.jsonc to a cache path) if you care about it at all.

### [UNCERTAIN] 7. Qt: hand-written qt5ct.conf / qt6ct.conf with color_scheme_path

**Evidence:** The supporting facts all check out. Noctalia's qt template writes ONLY the palette: builtin.toml:180-184 `output_path = ["$XDG_CONFIG_HOME/qt5ct/colors/noctalia.conf", "$XDG_CONFIG_HOME/qt6ct/colors/noctalia.conf"]` with no post_hook, and assets/templates/qt/qtct.conf contains only `[ColorScheme]` + active_colors/disabled_colors/inactive_colors — so something else genuinely must select it. `grep -rn 'qt5ctSettings|qt6ctSettings'` across home-manager 26.05's modules/ returns NOTHING, confirming those options do not exist and that stylix/modules/qt/hm.nix:118-119 only gets away with using them because the target never evaluates here. ~/.config/qt6ct/qt6ct.conf exists as a plain 207-byte file containing just `[SettingsWindow] geometry=...`, so the "would be clobbered" abort is real — `rm` it before the switch. The `"Name,size"` font form has in-tree precedent at stylix/modules/qt/hm.nix:108-111. What remains unproven is the load-bearing key itself: `color_scheme_path` appears nowhere in the Noctalia tree, nowhere in Stylix, and the live qt6ct.conf has never been written by qt6ct's Appearance tab.

**Correction:**

Ship it, but treat `color_scheme_path` as the one thing to validate by hand: launch `qt6ct`, open Appearance, and confirm "Color scheme" shows `noctalia` rather than blank. Also confirm `env | grep QT_STYLE_OVERRIDE` stays EMPTY after the change — it is empty today, which is why `style=Fusion` will be honoured, but stylix/modules/qt/nixos.nix sets `qt.style = recommendedStyle.qtct = "kvantum"` on the NixOS side, and if that ever starts exporting QT_STYLE_OVERRIDE you would get kvantum with no kvantum theme installed (the HM target that generated Base16Kvantum is dead).

### [CONFIRMED] 8. Wallpaper: interval 1800, transition set, edge_smoothness, transition_on_startup, recursive=false

**Evidence:** Every key and value is legal. example.toml:99-121: `fill_mode = "crop"` is in the enum `center|crop|fit|stretch|repeat|span`; `transition` default list is `["fade", "wipe", "disc", "stripes", "zoom", "honeycomb"]` so fade/wipe/zoom are all valid members; `transition_duration = 1500`, `edge_smoothness = 0.3`, `transition_on_startup = false`, `directory_light`/`directory_dark` all present; `[wallpaper.automation]` has enabled / interval_seconds / order (`random | alphabetical`) / `recursive = true`. wallpapers/ really does hold 27 files. The HM symlink note is right too — noctalia.nix's `home.file.".config/wallpapers".recursive = true` is HM's per-file-symlink flag and is orthogonal to noctalia's automation.recursive.

**Correction:**

One simplification worth taking: example.toml:120 shows `interval_seconds = 1800` is ALREADY Noctalia's default. The repo's `interval_seconds = 300` is a local override, so the change is "delete the line", not "set it to 1800" — which matches this file's stated convention of holding only deviations from defaults. Separately, the claim that directory_dark/directory_light "only do anything when mode = auto" is plausible but I did not find it stated in the source; since neither is being set, it costs nothing either way.

### [CONFIRMED] 9. Starship: programs.starship.configPath + a [theme.templates.user.starship] entry

**Evidence:** All four load-bearing facts verified in home-manager modules/programs/starship.nix: :18 `hasGeneratedConfig = cfg.settings != { } || cfg.presets != [ ]`; :110-117 `configPath = mkOption { type = lib.types.str; default = "${config.xdg.configHome}/starship.toml"; }`; :139 `sessionVariables.STARSHIP_CONFIG = cfg.configPath;` (unconditional); :141 `file.${cfg.configPath} = mkIf hasGeneratedConfig (...)`. So `settings = { }` really does export the variable while writing no file. The reason this app needs the different treatment is also confirmed: assets/templates/starship/apply.sh has no idempotent branch — it always rebuilds via awk and ends at `cat "$tmp_file" >"$config_file"`, which is EACCES against a store symlink (the `cmp -s` guard cannot save it, because HM's generated file can never equal one carrying the NOCTALIA STARSHIP PALETTE block). User-template shape and `$XDG_CACHE_HOME` expansion are documented at docs/user/theming/app-theming.mdx, "User Templates": `input_path`/`output_path`/`post_hook`, with "A leading $XDG_CONFIG_HOME, $XDG_DATA_HOME, $XDG_STATE_HOME, or $XDG_CACHE_HOME token is expanded". The builtin starship template is correctly left out of builtin_ids.

**Correction:**

One trap the design gets right by accident and should get right on purpose: docs/user/theming/app-theming.mdx, "Config Location", says every `~/.config/noctalia/*.toml` is loaded as a config overlay. `xdg.configFile."noctalia/templates/starship.toml"` is safe ONLY because it sits in the templates/ subdirectory (the glob is not recursive). Never flatten it to `xdg.configFile."noctalia/starship.toml"` — that would be parsed as Noctalia config and produce a fourth silently-discarded block, the exact failure mode this review exists to prevent.

### [CONFIRMED] 10. hooks.colors_changed key + tmux source-file pre-wire + dropping tmuxPlugins.catppuccin

**Evidence:** Hook key and shape verified in the C++: src/config/config_types.h:1394-1395 `{HookKind::WallpaperChanged, "wallpaper_changed", ""}, {HookKind::ColorsChanged, "colors_changed", ""}`, and example.toml:486-487 shows the list form. Live `noctalia theme --list-templates` startup banner prints `hooks kinds with commands=0`, confirming none are configured today. tmux output path confirmed: ~/.local/state/noctalia/community-templates/tmux/template.toml → `output_path = "$XDG_CONFIG_HOME/tmux/themes/noctalia.conf"`, `post_hook = "bash '{{ config_dir }}/apply.sh'"`. The catppuccin plugin really is there to remove: modules/home-manager/terminal/tmux.nix has `tmuxPlugins.catppuccin` with `set -g @catppuccin_flavor 'mocha'`, and the existing extraConfig is exactly the `set -g status-position top` the design edits.

**Correction:**

The tmux apply.sh payload is not cached, so `source-file -q ~/.config/tmux/themes/noctalia.conf` is a guess at what it wants — but it is a safe guess: `-q` makes it a no-op before the first render, and if the script also tries to edit ~/.config/tmux/tmux.conf (a store symlink) it will just log an error and the .conf still lands. Ship as written; read the fetched apply.sh afterwards.

### [CONFIRMED] 11. flake/lib/theme.nix shared Stylix base

**Evidence:** The placement argument holds exactly: flake/lib/registry.nix is a bare function that only walks the directory it is handed, and flake/modules/exports.nix hands it `../../modules/nixos` and `../../modules/home-manager` and nothing else — so flake/lib/ is never scanned and a plain attrset there cannot be mistaken for a module. Relative depth is right from both callers: modules/home-manager/core/ and modules/nixos/desktop/ are each three levels below the repo root, so ../../../flake/lib/theme.nix resolves identically. The `//` shallow merge is safe because the shared attrset defines no `targets` key and each caller defines nothing else the shared file also defines.

**Correction:**

Correct one piece of the rationale: `homeManagerIntegration.followSystem` and `.autoImport` are not merely 'dead because HM is standalone' — stylix/stylix/home-manager-integration.nix:192 and :204 show BOTH already default to `true`. The two lines in modules/nixos/desktop/stylix.nix restate defaults, so deleting them is a strict no-op, which is a stronger reason to delete them than the one given. Also keep the CLAUDE.md rule front and centre: flake/lib/theme.nix must be `git add`ed in the SAME commit as the two stylix.nix edits, or flake evaluation will not see it and the NixOS side will still carry the stale 43MB image path.

## Proposed changes

### 1. (high) Noctalia theme block: wallpaper source, m3-content, drop the Stylix bridge palette

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** This is the keystone flip. Three sub-decisions, each with a reason:

wallpaper_scheme = "m3-content". I measured the whole 27-image set with ImageMagick (mean HSL saturation, mean lightness, lightness stddev, plus a 4-colour quantisation). The set is overwhelmingly dark, low-chroma blue-grey: 16 of 27 images quantise to essentially the same ramp (#1D1F2D -> #353647 -> #4C4F61 -> #7B869E). Only Clearnight (sat 0.78), Rainnight (0.73) and Cloudsnight (0.54) are strongly chromatic. That measurement is what picks the generator. The three 'custom' desaturating generators — muted, soft, faithful — apply a second desaturation on top of an already-grey seed and yield a colourless desktop; faithful is the closest of the three but loses for exactly this reason. m3-monochrome collapses to one hue, which on this set is barely distinguishable from greyscale. dysfunctional is deliberately off-kilter and offers no contrast guarantee across 27 varied images. m3-fruit-salad and m3-rainbow spread accents across the wheel, which is wrong for a bar whose capsules use primary/secondary/tertiary together — three unrelated hues per wallpaper reads as chaos, not design. That leaves vibrant, m3-tonal-spot and m3-content. vibrant is the real runner-up: it guarantees a legible accent even on the grey images, but it is a custom generator, so it does not run the Material tonal-palette machinery — and the surface_container_lowest/low/…/highest ramp is precisely what the capsule + backdrop chrome design layers against, so I do not want to give up its tone guarantees. m3-tonal-spot is the safest for contrast but deliberately damps seed chroma, which on an already-desaturated set produces a washed accent. m3-content is the one combination that gives both: full M3 tonal ramp (so surface/on_surface contrast is computed by Material for every one of the 27 images) plus higher chroma retention (so the grey images still yield a visible accent). It is also already the effective default in your exported config, making this a zero-risk starting point. If it still reads too grey after a week, `vibrant` is a one-word swap.

mode = "dark", not "auto". mode is the app-facing mode: it selects the variant every template writes. "auto" would rewrite ghostty/btop/gtk/hyprland/qt config files twice a day on the [location] schedule — churn with no benefit on a three-monitor desktop in a fixed room.

shell_mode and pure_black_dark: deliberately NOT written. This file's own header says only deviations from defaults are set here. shell_mode defaults to "follow", which with mode pinned to dark is a no-op. pure_black_dark defaults to false and should stay false: these are three IPS LCD panels (HP V27e ×2, Acer XB252Q), not OLED — pure black shows as grey-with-backlight-bleed, and it collapses the surface_container ramp that the translucent-capsule chrome tints against.

customPalettes.stylix is deleted: it is the old bridge that fed Stylix's base16 into Noctalia, and it is dead once source = "wallpaper". Removing it also drops the last `config.lib.stylix.colors` reference in this file, which is the whole point of the migration.

**Verified against:** docs/user/theming/index.mdx (mode/shell_mode/source/wallpaper_scheme tables, full 10-value scheme enum) and docs/user/ipc/media-and-ui.mdx line 107 (same enum, second source) under .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/; `noctalia config export full` (current theme block: source=custom, custom_palette=stylix, wallpaper_scheme=m3-content); `noctalia config validate` on the proposed TOML -> "Config is valid", 0 warnings; ImageMagick measurement of all 27 files in wallpapers/

**Risk:** Low and fully reversible. If the generated accent is too weak, `noctalia msg color-scheme-set wallpaper vibrant` switches live without a rebuild, and you can then decide whether to commit it. Note `noctalia config validate` does NOT check this enum (I tested: it accepts `wallpaper_scheme = "m3-bogus"` silently) -- an invalid value falls back at runtime rather than failing the build.

```nix
# in programs.noctalia:
  # customPalettes.stylix = { ... };   <- DELETE the entire block (~60 lines).
  # It bridged Stylix's base16 into Noctalia; dead once source = "wallpaper".

  settings = {
    theme = {
      # Material You, regenerated from the current wallpaper on every rotation.
      source = "wallpaper";

      # m3-content keeps the full M3 tonal ramp (so surface/on_surface contrast
      # is guaranteed for every image) while retaining more seed chroma than
      # m3-tonal-spot -- which matters because 16 of the 27 wallpapers quantise
      # to the same low-saturation blue-grey. `vibrant` is the louder fallback.
      wallpaper_scheme = "m3-content";

      # The app-facing mode: this is the variant every template renders.
      # Not "auto" -- that would rewrite every templated app config twice a day.
      mode = "dark";

      # shell_mode ("follow") and pure_black_dark (false) stay at their defaults.
      # pure_black_dark must stay false: three IPS panels, not OLED, and the
      # capsule/backdrop chrome needs a non-zero surface tone to tint against.
    };
  };
```

### 2. (high) Stylix demotion: the exact target list, and stylix.image = null

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Nine targets to disable, chosen by cross-referencing which Stylix HM targets actually write a file on this machine against which apps Noctalia now templates. I got the live list by evaluating `homeConfigurations."deadmade@deadPc".config.xdg.configFile` before and after.

Each one and why: hyprland (Noctalia's hyprland template now writes the border colours; disabling the whole target rather than just the hyprpaper sub-option is correct because it ALSO drops Stylix's misc.background_color, which paints Catppuccin base under the wallpaper during workspace switches). gtk (this is the dangerous one -- see the risk field). ghostty, btop, bat, fzf, tmux, zed (all Noctalia-templated). nixcord (it is nixcord.nix, not vesktop.nix, that writes vesktop/themes/stylix.theme.css and forces enabledThemes = ["stylix.theme.css"]) plus vencord and vesktop, which are separate targets writing Vencord/themes/stylix.theme.css -- I only found this because the post-change evaluation still listed a Vencord file.

stylix.image = null. Three reasons. It is now a lie (dark-waves.jpg is not the wallpaper; Noctalia rotates 27). It is what auto-enables hyprpaper: stylix/modules/hyprland/hm.nix guards the hyprpaper sub-target with `autoEnable = image != null`, and that target sets services.hyprpaper.enable = true -- which is why hyprpaper is running and painting a dead layer under Noctalia's. And it drops a 43MB store copy. It is safe because base16Scheme is set: stylix/palette.nix:126 only throws when BOTH are unset. I checked the null-safety empirically rather than reading it: `stylix.targets.gnome` does `picture-uri = "file://${image}"`, which would be an eval error on null, but mkTarget skips a config block whose argument resolves to null -- I confirmed picture-uri is simply absent from the resulting dconf settings, with gnome.image.enable still true. Both nixosConfigurations.deadPc and the HM config evaluate to a drvPath with image = null.

What Stylix KEEPS owning: fonts (monospace/sansSerif/serif and fonts.sizes -- these are still the source of truth and are now read back explicitly by the gtk block in the next change), cursor (Bibata-Modern-Ice 25), opacity, librewolf (no Noctalia template; pywalfox exists but needs a manually installed native host and extension), fontconfig, font-packages, gtksourceview, and the gnome target's dconf font/cursor keys. Neovim is out of reach entirely -- it comes from a flake input, not from either theming system.

**Verified against:** stylix/modules/hyprland/hm.nix (hyprpaper autoEnable = image != null; the target sets services.hyprpaper.enable), stylix/modules/discord/{nixcord,vencord,vesktop}.nix, stylix/modules/gtk/hm.nix, stylix/stylix/palette.nix:120-131 (the throw condition), stylix/stylix/mk-target.nix:326 (config = mkIf (stylix.enable && cfg.enable)) under .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/; target names are directory names under stylix/modules/ per stylix/stylix/autoload.nix; before/after `nix eval` of homeConfigurations."deadmade@deadPc".config.xdg.configFile

**Risk:** The gtk one is the only real hazard and it is why this change exists. Noctalia's gtk apply.sh (assets/templates/gtk/apply.sh, ensure_gtk_css_import) explicitly handles a read-only symlinked gtk.css by DELETING the symlink and writing a plain file in its place -- the comment in the script literally says "Read-only symlink (e.g. NixOS)". If you leave stylix.targets.gtk on, Noctalia will unlink a Home-Manager-owned file and your next `nhs` will abort with "would be clobbered". Disabling the target removes gtk.css from Home Manager entirely so Noctalia creates it fresh. Do this BEFORE the first Noctalia theme render, not after.

```nix
    targets = {
      # --- Noctalia now owns the colours for these -------------------------
      # Disabling the whole hyprland target (not just .hyprpaper) also drops
      # Stylix's misc.background_color, which painted base00 under the wallpaper.
      hyprland.enable = false;
      gtk.enable = false; # frees ~/.config/gtk-{3,4}.0/gtk.css for Noctalia
      ghostty.enable = false;
      btop.enable = false;
      bat.enable = false;
      fzf.enable = false;
      tmux.enable = false;
      zed.enable = false;
      # Three separate targets write a Discord theme; nixcord is the one that
      # produced vesktop/themes/stylix.theme.css here.
      nixcord.enable = false;
      vencord.enable = false;
      vesktop.enable = false;

      # --- Stylix keeps these ----------------------------------------------
      hyprlock.enable = false; # unchanged
      starship.enable = false; # unchanged; see the starship change
      librewolf.profileNames = ["Default"]; # no Noctalia template exists
    };

    # And in the shared base (see flake/lib/theme.nix):
    #   image = null;
    # Safe because base16Scheme is set (stylix/palette.nix:126 only throws when
    # both are null). This is also what stops Stylix auto-enabling hyprpaper.
```

### 3. (high) Re-plumb GTK by hand now that stylix.targets.gtk is off (and set gtk4.theme = null)

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Turning the gtk target off drops more than gtk.css: evaluation shows gtk.theme and gtk.font both become null (gtk.enable stays true, set by another module). Noctalia's gtk apply.sh calls `gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark` in dark mode -- and Home Manager's gtk3 module writes the SAME dconf keys (modules/misc/gtk/gtk3.nix:148-167). Left mismatched, the two ping-pong on every rebuild and every wallpaper rotation. Setting gtk.theme.name = "adw-gtk3-dark" and gtk.colorScheme = "dark" makes both writers agree by construction, so the fight never happens.

The font must be read back from config.stylix.fonts rather than hardcoded. I tried `size = 11` first and the evaluator rejected it: stylix.targets.gnome also defines dconf font-name ("Montserrat 12", from stylix.fonts.sizes.applications) and the two conflicted outright. Deriving from config.stylix.fonts is not just a workaround -- it is the architecture stated out loud: Stylix keeps owning fonts, we only re-plumb them into gtk because we turned its own gtk target off.

gtk4.theme = null is load-bearing and I nearly missed it. With home.stateVersion < 26.05, gtk.gtk4.theme legacy-defaults to config.gtk.theme, and that makes Home Manager write ~/.config/gtk-4.0/gtk.css even with the Stylix gtk target disabled -- reopening exactly the clobber hole the previous change closes. Setting it null is also correct on the merits: adw-gtk3 has no GTK4 stylesheet, and Noctalia's gtk4.css redefines the entire libadwaita @define-color set (accent_*, window_*, view_*, headerbar_*, popover_*, card_*, sidebar_*), so GTK4 apps get Adwaita's widget CSS with Noctalia's colours. It also silences the stateVersion warning.

Papirus-Dark fixes a standing defect -- no icon theme is set anywhere today. I am NOT recommending the papirus-icons community template: it recolours the icon theme in place, and yours lives read-only in /nix/store.

**Verified against:** home-manager modules/misc/gtk/gtk3.nix:139 (gtk.css written only when extraCss != ""), :148-167 (dconf gtk-theme/icon-theme/color-scheme), modules/misc/gtk/lib.nix:63-80 (colorScheme -> gtk-application-prefer-dark-theme) under .direnv/flake-inputs/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/; noctalia assets/templates/gtk/apply.sh (sync_system_appearance picks adw-gtk3-dark for mode=dark) and assets/templates/gtk/gtk4.css; two `nix eval` runs -- the first failed on the dconf font-name conflict, the final one returns warns=[] and no gtk.css entries

**Risk:** pkgs.adw-gtk3 and pkgs.papirus-icon-theme are added to the closure (both small). Noctalia's apply.sh checks that adw-gtk3-dark exists in ~/.themes, XDG_DATA_HOME/themes or the XDG_DATA_DIRS theme paths before calling gsettings; Home Manager's gtk module puts theme packages on the profile path, so this resolves -- but if icons or the theme do not appear, that lookup is the first thing to check.

```nix
  # Stylix still owns fonts and cursor; because stylix.targets.gtk is off we
  # re-plumb them into gtk ourselves. Reading them back from config.stylix.fonts
  # (rather than hardcoding) is required: stylix.targets.gnome defines the same
  # dconf font-name key and a literal mismatch is an eval error.
  gtk = {
    enable = true;

    # Must match what Noctalia's gtk apply.sh sets via gsettings in dark mode,
    # or Home Manager and Noctalia overwrite each other's dconf keys forever.
    colorScheme = "dark";
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };

    # No icon theme was set anywhere before this.
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

    font = {
      inherit (config.stylix.fonts.sansSerif) package name;
      size = config.stylix.fonts.sizes.applications;
    };

    # Legacy default (stateVersion < 26.05) is config.gtk.theme, which makes HM
    # write gtk-4.0/gtk.css -- the exact file Noctalia's apply.sh would unlink.
    # adw-gtk3 has no GTK4 stylesheet anyway; Noctalia's gtk4.css redefines the
    # whole libadwaita @define-color set.
    gtk4.theme = null;
  };

# NOTE: this module must now take `config` in its argument set.
```

### 4. (high) Hyprland <-> Noctalia handshake in the Lua config, plus a hyprctl reload hook

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** This is the subtle one and it does not work by default. The builtin hyprland template is not a plain file write: it uses input_path_dynamic/output_path_dynamic, both driven by assets/templates/hyprland/apply.sh. That script probes `hyprctl dispatch 'hl.dsp.no_op()'`, sees 'ok', selects Lua mode, renders hyprland.lua -> ~/.config/hypr/noctalia.lua, and then its post_hook tries to APPEND `require("noctalia").apply_theme()` to ~/.config/hypr/hyprland.lua. That file is a /nix/store symlink. The append is `printf ... >>"$lua_config_file"` under `set -euo pipefail`, so it fails with EACCES and the hook dies.

The fix is to put the include there ourselves. apply.sh guards the append with `grep -qF 'require("noctalia")'` -- a fixed-string check that grep can satisfy by reading the symlink. So as long as our Lua contains that literal substring, apply.sh finds it, skips the append, and never writes anything.

That constrains the wording. `pcall(require, "noctalia")` would be the idiomatic guard but does NOT contain the literal, so apply.sh would try to append and fail. `pcall(function() return require("noctalia") end)` does contain it, and still survives the first boot before Noctalia has rendered noctalia.lua.

The package.loaded bust handles a second problem: Noctalia rewrites noctalia.lua on every wallpaper rotation but nothing tells Hyprland, so borders would stay at the boot palette until the next Hyprland restart. `hyprctl reload` re-executes the config; if it reuses the Lua state, `require` returns the cached module with stale colours. Clearing package.loaded first makes reload correct either way. Reload is safe here specifically because the only side effect in this config is inside `hl.on("hyprland.start", ...)`, which does not re-fire.

Placement is near the top, right after the hyprsplit require, so `noctalia.colors` is in scope for the rest of the file. The module returns exactly seven "rgb(rrggbb)" strings -- primary, surface, on_surface, secondary, on_secondary, error, on_error -- which is what the animations/decoration work should build gradient borders and shadow colours from. `require("noctalia")` resolves because Hyprland puts ~/.config/hypr on the Lua package.path: hyprsplit already proves it (require("hyprsplit") -> ~/.config/hypr/hyprsplit/init.lua, and `hyprctl binds` shows 459 registered binds, which cannot happen if that require had raised).

**Verified against:** noctalia assets/templates/builtin.toml ([templates.hyprland] uses input_path_dynamic/output_path_dynamic/post_hook), assets/templates/hyprland/apply.sh (detect_mode, apply_lua, the grep -qF guard) and assets/templates/hyprland/hyprland.lua (the returned colors table) under .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/; live ~/.config/hypr/ listing showing hyprland.lua is a store symlink; `hyprctl binds` (459 binds -> hyprsplit's require resolved)

**Risk:** Disabling the hyprland template later runs undo.sh, which awk-rewrites hyprland.lua to strip the include -- that write hits the store symlink and fails. Harmless (the file is regenerated by Home Manager anyway) but it will log an error. Also: `hyprctl reload` every 30 minutes re-executes the whole config, so any future side effect added to extraConfig must stay inside hl.on("hyprland.start", ...).

```nix
# In extraConfig, immediately after the hyprsplit require:

      -- Noctalia colour templates. The `hyprland` builtin template renders
      -- ~/.config/hypr/noctalia.lua on every palette change.
      --
      -- Two constraints shape this wording:
      --  * apply.sh does `grep -qF 'require("noctalia")'` on this file and only
      --    appends the include when it is missing. That append targets a
      --    /nix/store symlink and would fail, so the literal string must appear
      --    here verbatim -- `pcall(require, "noctalia")` would NOT satisfy it.
      --  * clearing package.loaded makes `hyprctl reload` (fired by the
      --    colors_changed hook) re-read a freshly rendered palette instead of a
      --    cached module.
      package.loaded["noctalia"] = nil
      local ok_noctalia, noctalia = pcall(function() return require("noctalia") end)
      if ok_noctalia then
        noctalia.apply_theme()
      end
      -- noctalia.colors = { primary, surface, on_surface, secondary,
      --   on_secondary, error, on_error } as "rgb(rrggbb)" strings, e.g.
      --   hl.config({ general = { col = { active_border =
      --     noctalia.colors.primary .. " " .. noctalia.colors.secondary .. " 45deg" } } })
```

### 5. (high) Pre-seed the theme names so each template's apply.sh takes its no-op branch

**File:** `modules/home-manager/terminal/ghostty.nix`

**Rationale:** Same class of problem as the Hyprland include, four more times. Every one of these apply scripts wants to edit a config file that Home Manager owns as a read-only store symlink -- but each starts with an early-exit branch when the correct line is already present. Writing that line declaratively converts a guaranteed failure into a clean no-op, and the script still runs its live-reload step, which is what makes colour changes appear without restarting anything.

ghostty: apply.sh tests `grep -qE '^theme\s*=\s*noctalia$'` first. Home Manager renders string settings unquoted with spaces -- the live config today reads `theme = stylix` on line 19 -- so `settings.theme = "noctalia"` produces exactly `theme = noctalia` and matches. It then runs reload.sh, which reloads via the systemd unit, or gdbus reload-config, or SIGUSR2. Live, no restart.

btop: `grep -qE '^color_theme\s*=\s*"noctalia"'`. Home Manager quotes strings here -- the live btop.conf reads `color_theme = "stylix"` -- so this matches too, then `pkill -SIGUSR2 -x btop`. Live.

zed: replace the existing `lib.mkForce "Catppuccin Mocha"` rather than adding a second definition. I tried adding one in the eval harness and got a mkForce-vs-mkForce conflict, which is the correct signal that this is an edit, not an addition.

nixcord: stylix/modules/discord/nixcord.nix pins enabledThemes = ["stylix.theme.css"], so this only works once that target is off. The discord community template writes three variants alongside each other (noctalia.theme.css "midnight", noctalia-material.theme.css, discord-system24.css), so switching is a one-word edit.

**Verified against:** noctalia assets/templates/{ghostty,btop}/apply.sh and ghostty/reload.sh under .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/; live ~/.config/ghostty/config line 19 (`theme = stylix`, unquoted) and ~/.config/btop/btop.conf line 1 (`color_theme = "stylix"`, quoted) confirming HM's rendering matches each regex; ~/.local/state/noctalia/community-templates/{zed,discord}/template.toml for the output paths; stylix/modules/discord/nixcord.nix:56 (enabledThemes pin); `nix eval` confirming programs.ghostty.settings.theme resolves to ["noctalia"]

**Risk:** bat is the weak link -- I could not read its community apply.sh (payload not cached) and its live config uses `--theme=base16-stylix`, a different syntax from the two I verified. If its matcher differs the post_hook errors into `journalctl --user -u noctalia` and bat keeps its old theme; the .tmTheme file still lands. bat also needs `bat cache --build` to see a new theme, which I am assuming the script does.

```nix
# modules/home-manager/terminal/ghostty.nix
    settings = {
      # Noctalia's ghostty template writes ~/.config/ghostty/themes/noctalia and
      # its apply.sh wants to set this line itself -- but this file is a store
      # symlink. Declaring it makes the script take its no-op branch and go
      # straight to reload.sh, so the palette applies live.
      theme = "noctalia";
      # font-family and background-opacity still come from Stylix.
    };

# modules/home-manager/core/btop.nix
  programs.btop.settings = {
    vim_keys = true;
    color_theme = "noctalia"; # same trick; apply.sh then SIGUSR2s a running btop
  };

# modules/home-manager/terminal/zsh.nix (programs.bat)
  programs.bat.config.theme = "noctalia";

# modules/home-manager/coding/zed.nix -- EDIT line 42, do not add a second def
      theme = lib.mkForce "Noctalia"; # was "Catppuccin Mocha"; verify the exact
                                      # name inside ~/.config/zed/themes/noctalia.json

# modules/home-manager/socialMedia/vencord.nix
  programs.nixcord.config.enabledThemes = ["noctalia.theme.css"];
  # noctalia-material.theme.css and discord-system24.css are written alongside.
```

### 6. (high) Template roster: which builtin_ids and community_ids, matched to installed apps

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Today builtin_ids is ["kitty"] and programs.kitty.enable = false -- Noctalia is theming an app that does not run while ghostty, the real terminal, is left to Stylix. I walked the repo for what is actually installed rather than what sounds plausible.

Six builtins. hyprland, ghostty, btop, gtk3, gtk4 are the obvious ones. qt is the biggest single win and the least obvious: stylix.targets.qt autoEnables on `nixosConfig != null`, and these are standalone homeConfigurations, so nixosConfig is null and the target has been silently off the whole time -- which is exactly why ~/.config/qt6ct/colors is empty and every Qt app is unthemed. kcolorscheme earns its place because pkgs.unstable.kdePackages.okular is in systemPackages; qt5ct alone does not colour Kirigami apps, and its post_action merges a real colour scheme into kdeglobals. Everything else is dropped for cause: cava/alacritty/foot/wezterm/emacs/helix are not installed, niri/sway/labwc/mango/scroll/umbriel are other compositors, kitty is disabled, and starship gets its own treatment below because its apply.sh cannot write a store-symlinked starship.toml.

Community ids, all matched to something in the repo: zed (programs.zed-editor), discord (nixcord.vesktop, plus legcord is in systemPackages and gets a file too), tmux, bat, fzf, fastfetch, vscode (pkgs.unstable.vscode is in systemPackages even though the HM vscodium module is disabled -- and both its entries carry requires_path guards, ~/.vscode and ~/.vscode-oss, so they self-skip), obsidian, obs (obs-studio installed), heroiclauncher (heroic comes in via the gaming profile; guarded by requires_path ~/.config/heroic), and claude-code, which writes ~/.claude/themes/noctalia.json with no hook at all -- pure win.

Deliberately excluded: steam (deadPc has no gaming profile, and unlike heroiclauncher the steam entry has no requires_path, so it would create a skin directory tree for a launcher that is not there), papirus-icons (recolours the icon theme in place; yours is read-only in /nix/store), spicetify (needs spicetify), pywalfox (would need a manually installed native host + extension for LibreWolf).

On network: enable_community_templates defaults to true and plugins.auto_update defaults to "all". Community templates are fetched from api.noctalia.dev into ~/.local/state/noctalia/community-templates/ -- mutable state outside the Nix store, and shell.offline_mode = true would block it. That is a genuine reproducibility compromise and you should make it knowingly. The clean second phase is to vendor the two or three you actually keep as [theme.templates.user.*] entries whose input files Home Manager writes; the starship change below is the worked pattern.

**Verified against:** `noctalia theme --list-templates` (live catalogue, 21 builtins + 66 cached community ids); noctalia assets/templates/builtin.toml (every builtin's input/output/post_hook); ~/.local/state/noctalia/community-templates/*/template.toml for each id above (output paths and requires_path guards read individually); docs/user/theming/app-theming.mdx (community fetch + offline_mode); stylix/modules/qt/hm.nix (autoEnable = nixosConfig != null -- why Qt is currently unthemed); repo: modules/nixos/desktop/packages.nix, modules/home-manager/{coding/zed.nix,terminal/tmux.nix,socialMedia/vencord.nix,gaming/default.nix}

**Risk:** I verified output paths only, never payloads -- nothing but template.toml is cached until a template is enabled. Enable them in two passes: builtins first (fully readable in-store, so fully predictable), then community, watching `journalctl --user -u noctalia -f` for hook failures on the first render.

```nix
      theme.templates = {
        enable_builtin_templates = true;
        builtin_ids = [
          "hyprland" # borders + group colours, via ~/.config/hypr/noctalia.lua
          "ghostty" # the real terminal (kitty is enable = false -- was wrong here)
          "btop"
          "gtk3"
          "gtk4" # nautilus and every libadwaita app
          "qt" # stylix.targets.qt is dead on standalone HM, so Qt is unthemed today
          "kcolorscheme" # kdePackages.okular; qt5ct alone does not colour Kirigami
        ];

        # Fetched from api.noctalia.dev into ~/.local/state/noctalia/, i.e.
        # mutable state outside the store. shell.offline_mode must stay false.
        enable_community_templates = true;
        community_ids = [
          "zed"
          "discord" # vesktop + legcord
          "tmux"
          "bat"
          "fzf"
          "fastfetch"
          "vscode" # requires_path-guarded; inert until ~/.vscode exists
          "obsidian"
          "obs"
          "heroiclauncher" # requires_path = ~/.config/heroic
          "claude-code" # ~/.claude/themes/noctalia.json, no hook, zero risk
        ];
      };
```

### 7. (medium) Qt: point qt5ct/qt6ct at the colour scheme Noctalia writes

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** The qt builtin template writes only the palette -- qt5ct/colors/noctalia.conf and qt6ct/colors/noctalia.conf, with no post_hook. Nothing selects it. QT_QPA_PLATFORMTHEME=qt5ct is already exported (by the NixOS stylix qt target, which sets qt.platformTheme = "qt5ct" and nothing else useful), and ~/.config/qt6ct/qt6ct.conf currently contains a single window-geometry line, so Qt apps are running fully unthemed.

Stylix's own qt HM target drives these through `qt.qt5ctSettings` / `qt.qt6ctSettings`, which do NOT exist in home-manager release-26.05 -- I grepped the whole HM module tree and found nothing. Stylix gets away with it because the target is dead on standalone HM. So the ini has to be written directly.

style=Fusion, not kvantum: Kvantum would need a Kvantum theme, and the one Stylix generated goes away with the target. Fusion honours a custom palette natively, which is the whole mechanism here. The [Fonts] two-field form is copied from Stylix's own qtctSettings (`"Name,size"`), so it is a format with in-tree precedent rather than one I invented.

**Verified against:** noctalia assets/templates/builtin.toml ([templates.qt] -> both colours paths, no post_hook) and assets/templates/qt/qtct.conf ([ColorScheme] active/disabled/inactive_colors); stylix/modules/qt/hm.nix:88-120 (autoEnable = nixosConfig != null; qtctSettings shape and the "Name,size" font form) and stylix/modules/qt/nixos.nix (sets qt.platformTheme = "qt5ct"); grep for qt5ctSettings across home-manager 26.05 modules -> no match; live: `env | grep QT_` shows QT_QPA_PLATFORMTHEME=qt5ct, ~/.config/qt6ct/colors is empty

**Risk:** ~/.config/qt6ct/qt6ct.conf exists as a plain file today -- `rm` it before the first switch or Home Manager aborts with "would be clobbered". Once it is a store symlink qt6ct can no longer save its window geometry (harmless). Qt apps read the colour scheme at startup, so unlike ghostty/btop they need a restart to pick up a wallpaper rotation. And color_scheme_path is the one key here with no in-tree precedent -- confirm in qt6ct's Appearance tab.

```nix
  # Noctalia's qt template writes qt{5,6}ct/colors/noctalia.conf but nothing
  # selects it, and there is no qt.qt5ctSettings option in home-manager 26.05
  # (Stylix's qt target uses one, but that target is dead on standalone HM --
  # its autoEnable is `nixosConfig != null`). So write the ini directly.
  xdg.configFile = let
    qtct = ver: ''
      [Appearance]
      custom_palette=true
      color_scheme_path=${config.xdg.configHome}/qt${ver}ct/colors/noctalia.conf
      icon_theme=Papirus-Dark
      standard_dialogs=xdgdesktopportal
      style=Fusion

      [Fonts]
      fixed="${config.stylix.fonts.monospace.name},${toString config.stylix.fonts.sizes.applications}"
      general="${config.stylix.fonts.sansSerif.name},${toString config.stylix.fonts.sizes.applications}"
    '';
  in {
    "qt5ct/qt5ct.conf".text = qtct "5";
    "qt6ct/qt6ct.conf".text = qtct "6";
  };
```

### 8. (medium) Wallpaper: 1800s interval, trimmed transition set, and curation via recursive = false

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** interval 300 -> 1800 is your call. The knock-on is that a transition is now a rare event (two an hour) that also triggers a full palette regeneration and template re-render across the whole desktop, so it can afford to be more deliberate: 1800ms costs 0.1% of the interval. I want to be straight that this number is taste, not measurement -- three simultaneous 1920x1080 shader transitions is nothing for a 3070, and at 240Hz on the centre panel 1800ms is 432 frames. The reason to lengthen is the lower frequency, not performance.

transition_on_startup = true is the change with an actual argument behind it. At a 30-minute interval the login wallpaper is the one you look at for half an hour, so animating it in makes the greeter-to-desktop handoff read as intentional -- and it gives you a visible signal that the wallpaper daemon came up, which matters now that hyprpaper is gone and there is no second layer to mask a failure.

Transitions: drop stripes, honeycomb and disc. All three are geometric novelty wipes, and across 27 dark space/nature images they draw the eye to the mechanism rather than the picture. Keep fade (safe), wipe (reads as a pan, good across three panels) and zoom (pairs with the moment everything recolours). edge_smoothness 0.3 -> 0.4 only affects wipe: on dark low-contrast imagery it widens the seam enough to be invisible without degrading the wipe into a fade.

Curation. directory_dark/directory_light are the wrong tool -- they only do anything when mode = "auto", and mode is pinned to dark, so exactly one directory is ever consulted. The right tool is recursive = false (it defaults to true) plus a subdirectory: move outliers to wallpapers/archive/ and rotation ignores them while the files stay in git and stay symlinked. From the measurements, three candidates. grandfather-tree.jpg (mean lightness 0.598) and swirls.jpg (0.558) are the two bright images -- in dark mode M3 still builds a dark surface ramp so they will not wash the UI out, but they are the worst backdrop for a translucent bar and will fight the capsule design hardest. romb.png has the lowest lightness stddev in the set (0.050) -- a nearly flat image gives the seed extractor almost nothing to latch onto, so expect a near-neutral palette. Beyond those three, the broader honest note is that dark-waves, dark-forest, foggy-city, galaxy-waves, misty-boat, pixel-galaxy, satellite, space and trippy-purple all quantise to nearly the same slate ramp, so roughly 60% of rotations will land on a similar blue-grey accent. The Clearnight/Rainnight/Cloudsnight trio are the only strongly chromatic images and will be the most visibly different -- if you want the wallpaper-driven effect to feel dramatic, the fix is adding chromatic wallpapers, not changing the generator.

**Verified against:** noctalia example.toml lines 115-135 (every key above with its default and its comment) and `noctalia config export full` [wallpaper] / [wallpaper.automation] (confirming recursive and transition_on_startup are live keys, and interval_seconds is currently 300); `noctalia config validate` on the proposed block -> valid, 0 warnings; ImageMagick per-file mean saturation / mean lightness / lightness stddev / 4-colour quantisation over all 27 files in wallpapers/

**Risk:** recursive = false is the only functional change here; if you never create wallpapers/archive/ it is a no-op. transition_duration and edge_smoothness are pure taste and adjustable live in Settings. Note home.file.".config/wallpapers".recursive = true in this same file is Home Manager's symlink flag and is unrelated -- an archive/ subdirectory still gets symlinked, it just stops being rotated.

```nix
      wallpaper = {
        directory = "/home/${vars.username}/.config/wallpapers";
        fill_mode = "crop";

        # stripes/honeycomb/disc dropped: geometric novelty wipes that draw the
        # eye to the mechanism rather than the image across a dark 27-image set.
        transition = ["fade" "wipe" "zoom"];
        transition_duration = 1800; # rare event now; 0.1% of the interval
        edge_smoothness = 0.4; # only affects `wipe`; hides the seam on dark images
        transition_on_startup = true; # also a visible signal the daemon came up

        automation = {
          enabled = true;
          interval_seconds = 1800;
          order = "random";
          # Curation without deleting anything: park low-yield images in
          # wallpapers/archive/ and rotation stops seeing them.
          # Candidates by measurement: grandfather-tree.jpg (lightness 0.598),
          # swirls.jpg (0.558) -- too bright behind a translucent bar; and
          # romb.png (lightness stddev 0.050) -- too flat to seed a palette.
          recursive = false;
        };
        # directory_dark / directory_light deliberately unused: they only apply
        # when theme.mode = "auto", and mode is pinned to "dark".
      };
```

### 9. (medium) Starship: a user template plus programs.starship.configPath, instead of the builtin

**File:** `modules/home-manager/terminal/starship/default.nix`

**Rationale:** Starship is the one app where the pre-seed trick cannot work, and it is worth explaining why before the fix. Its apply.sh does not have a no-op branch: it always rebuilds the file (stripping the old NOCTALIA STARSHIP PALETTE block, re-inserting palette = "noctalia", appending the new block) and then does `cat "$tmp_file" >"$config_file"`. Against a store symlink that is EACCES, every time. And starship has no include mechanism, so the palette cannot live in a separate file.

The way out is an option I found in the home-manager source rather than the docs: programs.starship.configPath is a plain string option, and the module exports home.sessionVariables.STARSHIP_CONFIG from it while writing home.file at that path only `mkIf hasGeneratedConfig`. So setting settings = { } makes Home Manager write no file at all, while still exporting STARSHIP_CONFIG -- pointed wherever we like. Point it at a cache path Home Manager does not manage, and let Noctalia render the whole config there from a template that Home Manager DOES manage.

That inverts the problem nicely. Your prompt configuration stays in the repo, in git, as valid TOML. Only the colour values become {{ }} tokens. Noctalia re-renders the file on every palette change. No file is fought over, no network is needed, and it works with offline_mode -- which makes this the reference pattern for step two of the community-template story: any HM-managed app config Noctalia cannot safely edit can be converted the same way.

It also forces the starship.toml repair that is overdue anyway. Building the template means rewriting the [palettes.noctalia] block, which is where the undefined `purple`, the stray #83a598 and color_bg3 in [docker_context], `orange = "#cba6f7"` (which is mauve), the `fg:creen` typo and the dead [palettes.gruvbox_dark] block all live.

If you would rather not do the conversion now: leave the starship builtin out of builtin_ids, keep settings = pkgs.lib.importTOML ./starship.toml, and fix the palette by hand. Starship then keeps a static Catppuccin prompt while everything else follows the wallpaper -- the one accepted casualty.

**Verified against:** home-manager modules/programs/starship.nix:110-113 (configPath option), :139 (sessionVariables.STARSHIP_CONFIG = cfg.configPath), :141 (file.${cfg.configPath} = mkIf hasGeneratedConfig) under .direnv/flake-inputs/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/; noctalia assets/templates/starship/apply.sh (unconditional `cat > $config_file`, no idempotent branch); docs/user/theming/app-theming.mdx (user template shape) and templates.mdx (token/format/filter reference, $XDG_CACHE_HOME expansion); `noctalia config validate` with the [theme.templates.user.starship] block -> valid; `nix eval` confirming STARSHIP_CONFIG resolves to /home/deadmade/.cache/starship/starship.toml with no HM file written there

**Risk:** On a fresh login before Noctalia's first render the file does not exist and starship falls back to its built-in default prompt for that one session -- self-healing, but startling once. The tokenisation is a manual rewrite of a file you care about, so do it in a separate commit from the rest of this migration.

```nix
# modules/home-manager/terminal/starship/default.nix
{ config, ... }: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    # Empty settings => HM writes no starship.toml (home.file is mkIf
    # hasGeneratedConfig) but STILL exports STARSHIP_CONFIG = configPath.
    # Noctalia renders the whole file there from the template below.
    settings = { };
    configPath = "${config.xdg.cacheHome}/starship/starship.toml";
  };

  # The template input lives in the repo, so this stays fully declarative and
  # needs no network -- unlike the community templates.
  xdg.configFile."noctalia/templates/starship.toml".source = ./starship.toml.tmpl;
}

# starship.toml.tmpl -- your current starship.toml with the palette tokenised.
# Still valid TOML, so it can be linted. This is also the moment to fix the
# half-migrated Gruvbox palette (undefined `purple`, `fg:creen`, the stray
# #83a598 / color_bg3 in [docker_context], the dead [palettes.gruvbox_dark]).
#   palette = "noctalia"
#   [palettes.noctalia]
#   primary  = "{{ colors.primary.default.hex }}"
#   surface  = "{{ colors.surface.default.hex }}"
#   red      = "{{ colors.terminal_normal_red.default.hex }}"
#   ...

# modules/home-manager/windowManager/hyprland/noctalia.nix
      theme.templates.user.starship = {
        input_path = "$XDG_CONFIG_HOME/noctalia/templates/starship.toml";
        output_path = "$XDG_CACHE_HOME/starship/starship.toml";
      };
```

### 10. (medium) Runtime propagation: colors_changed hook, and what reloads live vs. needs a restart

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Reading every apply script gives an exact answer to "does this actually appear when the wallpaper rotates", and it is worth writing down because the answer is not uniform.

Live, no action needed -- the template's own post_hook handles it: ghostty (reload.sh: systemd reload, else gdbus reload-config, else SIGUSR2), btop (pkill -SIGUSR2 -x btop), gtk (gsettings color-scheme is immediate; the @import'd noctalia.css depends on GTK's CSS file monitoring, which I could not confirm covers imports), zed and vesktop (both watch their themes directories).

Needs a hook: hyprland. The template's post_hook only ensures the include exists -- it never reloads the compositor. Without `hyprctl reload`, border colours stay at the boot palette until Hyprland restarts. This is the one genuine gap and the only hook I am proposing. Paired with the package.loaded bust in the Lua config it is correct whether or not Hyprland reuses its Lua state.

Needs a restart, no fix available: qt/kcolorscheme (Qt reads the colour scheme at app startup) and starship (the palette is read at shell init, so new shells only).

I checked and am NOT proposing several hooks that look tempting. wallpaper_changed is redundant -- colors_changed already fires after the palette resolves and after terminal templates are updated. A home.activation hook calling `noctalia msg templates-apply` is unnecessary: everything Noctalia writes (themes/noctalia, noctalia.css, noctalia.lua) sits outside Home Manager's file set, so a rebuild never clobbers it. And tmux gets a `source-file -q` in extraConfig rather than a hook, so nothing depends on an apply script I could not read.

**Verified against:** docs/user/automation/hooks.mdx (full event table; colors_changed fires "after the theme palette is resolved and terminal templates are updated") and docs/user/ipc/media-and-ui.mdx:102 (templates-apply) under .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/; `noctalia config export full` [hooks] (all 18 keys, all currently empty -- "hooks kinds with commands=0" in the startup log); assets/templates/{ghostty/reload.sh,btop/apply.sh,gtk/apply.sh}; ~/.local/state/noctalia/community-templates/tmux/template.toml; `noctalia config validate` with the hooks block -> valid

**Risk:** `hyprctl reload` re-executes the entire Lua config every 30 minutes. Safe in this config because the only side effect (launching librewolf) is inside hl.on("hyprland.start", ...), which does not re-fire on reload -- but that becomes a standing constraint on anything added to extraConfig later. Removing tmuxPlugins.catppuccin is a visible change to the status bar and worth doing as its own commit.

```nix
      # The hyprland template's post_hook only ensures the include line exists;
      # it never reloads the compositor. Without this the border colours stay at
      # the boot palette until Hyprland restarts.
      hooks = {
        colors_changed = ["hyprctl reload"];
      };

# modules/home-manager/terminal/tmux.nix -- pre-wire the include, same idea as
# ghostty/btop, so nothing depends on the community apply.sh I could not read.
# -q keeps tmux quiet before the first render.
    extraConfig = ''
      set -g status-position top
      source-file -q ~/.config/tmux/themes/noctalia.conf
    '';
# ...and drop tmuxPlugins.catppuccin from `plugins`: it draws the status bar in
# hardcoded Mocha and will fight whatever the noctalia template sets.
```

### 11. (medium) Stop the two stylix.nix copies drifting: a shared attrset in flake/lib/

**File:** `flake/lib/theme.nix`

**Rationale:** flake/lib/ is the right home and I checked the conventions before picking it. flake/lib/registry.nix is already a bare function imported by path from flake/modules/exports.nix, and the registry only walks modules/nixos and modules/home-manager -- so nothing under flake/lib/ is auto-discovered as a module, which is exactly what a plain attrset needs. Both stylix.nix files sit three levels down, so ../../../flake/lib/theme.nix resolves identically from each. Relative imports are already the house style (../../../wallpapers/dark-waves.jpg, import ../hosts/${host}/variables.nix).

The split falls out naturally: the shared file holds only what both module systems accept (enable, image, base16Scheme, autoEnable, polarity, opacity, cursor, fonts). Targets stay per-file because they genuinely differ -- targets.grub is NixOS-only, targets.hyprland/gtk/ghostty/... are HM-only -- and `//` is a shallow merge, so each file's `targets` key lands cleanly on an attrset that has none.

Two lines to drop while you are in there. homeManagerIntegration.followSystem/autoImport in the NixOS file are dead: homeConfigurations are standalone, so there is no NixOS-side HM config to follow, and leaving them in is what makes the duplication look accidental rather than deliberate. And the `stylix = lib.mkDefault { ... }` wrapper pushes default priority onto every leaf, which means the NixOS stylix settings silently lose to any definition anywhere -- I demonstrated this by hand, overriding stylix.image at normal priority in extendModules and having it win with no mkForce. Nothing in the tree currently overrides them, so dropping mkDefault is a one-line behavioural change with no present effect.

The alternative -- threading a `theme` arg through _module.args in flake/modules/constants.nix the way `vars` is -- would also work and is arguably more idiomatic, but it means editing specialArgs in both flake/modules/hosts.nix and home.nix. Heavier for the same result.

**Verified against:** repo: flake/lib/registry.nix (the walk covers only file/dir names under the given dir) and flake/modules/exports.nix (registry applied to ../../modules/nixos and ../../modules/home-manager only, so flake/lib/ is never scanned); flake.nix + flake/modules/{constants,hosts,home}.nix for the specialArgs alternative; stylix/stylix/palette.nix:126 (throw condition for a null image); `nix eval` on nixosConfigurations.deadPc.extendModules with { stylix.image = null; } at normal priority -> builds, which is what proves mkDefault is losing

**Risk:** flake/lib/theme.nix must be `git add`ed before it will evaluate -- untracked files are invisible to flake evaluation, and CLAUDE.md already flags this. Dropping lib.mkDefault means a future host wanting to override a Stylix setting must use lib.mkForce; nothing does today. The two files must be converted in the same commit or the NixOS side keeps a stale image path.

```nix
# flake/lib/theme.nix (new)
# Shared Stylix base, imported by both stylix modules so they cannot drift.
# A plain function, not a module: flake/lib/ is not walked by
# flake/lib/registry.nix (that only covers modules/nixos and modules/home-manager),
# so nothing here is auto-discovered.
{pkgs}: {
  enable = true;

  # Noctalia owns the wallpaper and the palette now. Safe because base16Scheme
  # is set -- stylix/palette.nix only throws when BOTH are null. This is also
  # what stops Stylix auto-enabling hyprpaper.
  image = null;
  base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

  autoEnable = true;
  polarity = "dark";
  opacity = {
    terminal = 0.8;
    desktop = 0.0;
  };
  cursor = {
    package = pkgs.unstable.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 25;
  };
  fonts = {
    monospace = {
      package = pkgs.unstable.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
    };
    sansSerif = {
      package = pkgs.unstable.montserrat;
      name = "Montserrat";
    };
    serif = {
      package = pkgs.unstable.montserrat;
      name = "Montserrat";
    };
  };
}

# modules/home-manager/core/stylix.nix
  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      targets = { /* the HM disable list */ };
    };

# modules/nixos/desktop/stylix.nix
#   drop the lib.mkDefault wrapper (it pushed default priority onto every leaf,
#   so these settings lost to any definition anywhere), and drop
#   homeManagerIntegration.* (dead: homeConfigurations are standalone).
  stylix =
    (import ../../../flake/lib/theme.nix {inherit pkgs;})
    // {
      targets.grub.enable = false;
    };
```

## Open questions

UNVERIFIED, in order of how likely they are to bite:

1. **Community template payloads.** `~/.local/state/noctalia/community-templates/` currently holds only each template's `template.toml` (I checked: `ls bat/` → `.noctalia-cache.json`, `template.toml`). The actual `apply.sh`/theme files are fetched from `api.noctalia.dev` on first enable. So I could verify every community template's *output path* but not one payload or apply script. Everything I say about community templates below is inferred from their `template.toml` only. This is also the reproducibility hole: community templates are mutable state outside the Nix store, and enabling them needs network (`shell.offline_mode` blocks it). Recommended path: enable them, then vendor the two or three you keep as `[theme.templates.user.*]` inputs written by Home Manager (the starship change below is a worked example of that pattern).

2. **Zed theme name.** I set `theme = "Noctalia"` but the real name is whatever is inside the rendered `~/.config/zed/themes/noctalia.json`. Check with `jq -r '.themes[].name' ~/.config/zed/themes/noctalia.json` after the first render and correct `modules/home-manager/coding/zed.nix` if it differs (likely "Noctalia Dark").

3. **`color_scheme_path` in qt6ct.conf.** It is the key qt6ct itself writes, but Stylix's own qt target does not use it (it drives colour through Kvantum instead), so I have no in-tree precedent. Verify by running `qt6ct` once and looking at Appearance → Color scheme. Also note `~/.config/qt6ct/qt6ct.conf` exists today as a plain file — `rm` it before the first switch or Home Manager will abort with "would be clobbered".

4. **`bat`, `tmux`, `fastfetch` apply scripts.** Same class of risk as ghostty/btop but I could not read the scripts. The pre-seed trick may not match their grep. Worst case the post_hook logs an error in `journalctl --user -u noctalia` and the theme file is still written — non-fatal. `bat` additionally needs `bat cache --build` to see a new theme; I am assuming its apply.sh does that.

5. **GTK live reload.** GTK3/GTK4 monitor `~/.config/gtk-3.0/gtk.css` and reload it, but I did not confirm they also monitor `@import`-ed files. If GTK apps do not repaint on wallpaper rotation, that is why. The gsettings `color-scheme` half is definitely live.

6. **`edge_smoothness`.** It is a real key (validated) but the 0→1 value is not documented in terms of pixels, so 0.3→0.4 is an educated nudge, not a computed one. It only affects `wipe`.

7. **Scheme comparison.** I wanted to run `noctalia theme wallpapers/dark-waves.jpg --scheme <s> --dark` across all ten generators to show you actual hex output, but the sandbox classifier blocked `noctalia theme` (it looks mutating; with no `-r`/`-c`/`-o` it only prints JSON to stdout). That command is the empirical check on my `m3-content` pick — run it yourself on `dark-waves.jpg` (the greyest image) and `Clearnight.jpg` (the most saturated) and compare `primary` and `surface` between `m3-content`, `vibrant` and `m3-tonal-spot`.

HOUSEKEEPING, outside Nix: `~/.config/hypr/noctalia/noctalia-colors.conf` is a stale v4 leftover from March. It is harmless today (Lua's `?.lua` search path beats `?/init.lua`, so `require("noctalia")` still resolves to `noctalia.lua`) but delete the directory. `~/.config/hypr/hyprland.conf` is also a stale writable stub from June; irrelevant in Lua mode, but it is what the template's `detect_mode` would fall back to writing if `hyprctl` were ever unreachable.
