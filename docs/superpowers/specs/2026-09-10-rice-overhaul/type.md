# Typography, icons, Qt/GTK

_Typography, icons, and Qt/GTK appearance (deadPc + deadConvertible)_

The through-line is that nothing currently owns appearance below the colour layer: Stylix picks a display face for UI work, no module sets an icon theme, `gtk.enable` is set on one host only, and the NixOS `qt` module is emitting `QT_QPA_PLATFORMTHEME=qt5ct` with no writer for the qt5ct/qt6ct colour files. I propose making Stylix the single source of truth for *fonts, sizes and cursor* only, adding a new `modules/home-manager/desktop/` domain (`gtk.nix`, `qt.nix`, `fonts.nix`) that owns shape/icons/Qt plumbing, and disabling exactly the three Stylix targets (`gtk`, `qt`, `ghostty`) that would otherwise fight Noctalia's templates for the same files. Two of those fights are not cosmetic: Noctalia's `gtk/apply.sh` deletes the Home Manager `gtk.css` symlink and its `ghostty/apply.sh` does `cat > ~/.config/ghostty/config`, which is a read-only store symlink — the first breaks the next `home-manager switch`, the second aborts the template with `set -e`. I also have to contradict the brief on one point: the `papirus-icons` community template hardcodes `/usr/share/icons/$variant` and calls `gsettings`, neither of which exists here, so it cannot recolour anything on NixOS.

## Fatal problems flagged by the verifier

Two things in this design will break the build or the desktop, and one more is a self-inflicted regression.

1. BUILD-BREAKING — the rewritten `modules/home-manager/terminal/ghostty.nix` references `config.stylix.*`, but that module is imported by `profiles/home-manager/wsl.nix` via `builtins.attrValues outputs.homeManagerModules.terminal`, and `homeConfigurations."deadmade@deadWsl"` has no stylix module. Verified: `nix eval .#homeConfigurations --apply 'h: builtins.tryEval (h."deadmade@deadWsl".config.stylix.fonts.sansSerif.name)'` → `error: attribute 'stylix' missing`. Four references (fonts.monospace.name, fonts.emoji.name, fonts.sizes.terminal, opacity.terminal) each fail. `nix flake check` and `home-manager switch --flake .#deadmade@deadWsl` both die. Correction is in the Change 9b verdict: keep `stylix.targets.ghostty` ENABLED and use `theme = lib.mkForce "noctalia";` plus the padding/chrome keys — that fixes both real ghostty defects (dead `background-blur`, duplicate `font-size`) with zero stylix coupling.

2. DESKTOP-BREAKING — adding `"btop"` to Noctalia's `builtin_ids` while `stylix.targets.btop.enable` is true (verified true) means Noctalia's `assets/templates/btop/apply.sh` will `cat "$tmp" >"$target"` onto `~/.config/btop/btop.conf`, which is a read-only store symlink, under `set -euo pipefail`. The design names this failure class in its own risk prose and then walks into it. Fix: `programs.btop.settings.color_theme = lib.mkForce "noctalia";` in modules/home-manager/core/btop.nix (live btop.conf already emits the quoted form the apply.sh greps for).

3. REGRESSION — `fonts.packages = config.stylix.fonts.packages;` in modules/nixos/desktop/stylix.nix duplicates what stylix's already-enabled `font-packages` target does (`nix eval .#nixosConfigurations.deadPc.config.stylix.targets.font-packages` → enable true; modules/font-packages/nixos.nix:2). `fonts.packages` is a listOf, so the line concatenates a second copy of every stylix font instead of deduplicating. The correct change is `git rm modules/nixos/core/themes.nix` and nothing else.

Three factual premises the plan rests on are also false and should be struck before this becomes a plan, because each one currently justifies work that is unnecessary: (a) home-manager DOES have `qt.qt5ctSettings`/`qt6ctSettings` — verified by `nix eval .#homeConfigurations."deadmade@deadPc".options.qt --apply builtins.attrNames` — so desktop/qt.nix should use the HM module, not hand-written INI; (b) `programs.dconf.enable` is ALREADY true and the dconf GIO backend IS registered via GIO_EXTRA_MODULES — the designer checked the wrong directory; (c) deadConvertible DOES have GTK settings, because stylix's own gtk target sets `gtk.enable = true` (modules/gtk/hm.nix:33, and the eval confirms it).

Finally, one unflagged loss: disabling `stylix.targets.gtk` also removes `flatpakSupport`, which today writes `~/.themes/adw-gtk3` and `~/.local/share/flatpak/overrides/global` (both live HM symlinks). Flatpak apps lose the forced GTK_THEME. Decide that deliberately rather than discovering it.

## Verdicts

### [CONFIRMED] Change 1 — Adwaita Sans / Source Serif 4 / emoji in modules/home-manager/core/stylix.nix

**Evidence:** stylix/fonts.nix:29-115 defines stylix.fonts.{serif,sansSerif,monospace,emoji}.{package,name} and stylix.fonts.sizes.{desktop,applications,terminal,popups}. Packages resolve: `nix eval .#nixosConfigurations.deadPc.pkgs.<p>.name` → adwaita-fonts-50.0, source-serif-4.005, noto-fonts-color-emoji-2.051. Family strings verified with fc-scan: /nix/store/b8gbdhi666cj91b9n83dac47627gla2i-adwaita-fonts-50.0/share/fonts/Adwaita/AdwaitaSans-Regular.ttf → "Adwaita Sans"; /nix/store/6jw2x034i7q2wl0yq8hi07x0kwqmsh6r-source-serif-4.005/.../SourceSerif4Variable-Roman.otf → "Source Serif 4". Current defect confirmed: `fc-match serif` → Montserrat-Regular.otf.

**Correction:**

One nit: the emoji block is not a fix, it is a restatement of the default. stylix/fonts.nix:48-52 already defaults emoji to package "noto-fonts-color-emoji", name "Noto Color Emoji", and `config.fonts.packages` on deadPc already contains noto-fonts-color-emoji-2.051. Keep it for explicitness but drop the "was implicit / removes the accident" framing. The x-height/upem ratios (0.546 vs 0.550 etc.) I did not re-measure — treat those numbers as the designer's, not verified.

### [CONFIRMED] Change 2 — mirror font/cursor block into modules/nixos/desktop/stylix.nix

**Evidence:** The two stylix definitions are genuinely independent: flake/modules/home.nix builds `flake.homeConfigurations` via home-manager.lib.homeManagerConfiguration (standalone), so `homeManagerIntegration.followSystem = true` in modules/nixos/desktop/stylix.nix:16 never fires. `nix eval .#nixosConfigurations.deadPc.config.fonts.fontconfig.defaultFonts` → {"sansSerif":["Montserrat"],"serif":["Montserrat"],...}, i.e. the system level really is still on Montserrat independently of HM.

### [WRONG] Change 3 — delete themes.nix AND add `fonts.packages = config.stylix.fonts.packages` to nixos/desktop/stylix.nix

**Evidence:** Stylix already ships a `font-packages` target that does exactly this and it is already ON. modules/font-packages/nixos.nix:2 is `mkTarget { config = { fonts }: { fonts = { inherit (fonts) packages; }; }; }`, and `nix eval .#nixosConfigurations.deadPc.config.stylix.targets.font-packages` → {"enable":true,...}. `config.fonts.packages` today already lists nerd-fonts-jetbrains-mono-3.5.0 + montserrat (twice) + noto-fonts-color-emoji, i.e. the stylix set, PLUS the 3.4.0 build from themes.nix. `fonts.packages` is a listOf, so a second definition concatenates — the proposed line adds each stylix font a second time rather than deduplicating anything.

**Correction:**

Drop the snippet entirely. The whole change is:

    git rm modules/nixos/core/themes.nix

Do NOT add `fonts.packages = config.stylix.fonts.packages;` and do NOT add `config` to the argument list of modules/nixos/desktop/stylix.nix. The duplicate-store-path diagnosis is right (fc-list shows both "JetBrains Mono" and "JetBrainsMono Nerd Font Mono" families, and both 3.4.0 and 3.5.0 nerd builds are in fonts.packages); deletion alone fixes it. The stated side effect on deadServer/deadPi is real — profiles/nixos/core.nix is `builtins.attrValues outputs.nixosModules.core` and those hosts do not import the stylix desktop module, so they lose nerd-fonts.jetbrains-mono system-wide.

### [WRONG] Change 4 — new modules/home-manager/desktop/gtk.nix: premise "deadConvertible has no GTK config at all"

**Evidence:** Stylix's HM gtk target sets `gtk.enable = true` itself — /nix/store/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/gtk/hm.nix:33. Live proof: `nix eval .#homeConfigurations."deadmade@deadConvertible".config.gtk.enable` → true and `.config.gtk.theme` → {"name":"adw-gtk3",...}. deadConvertible already writes a settings.ini. Separately, the stated reason for deleting `gtk = { enable = true; }` from hosts/deadPc/home.nix ("a second definition of the same option is a conflict") is false for types.bool, which merges with mergeEqualOption — verified: evalModules with two `foo = true` definitions of a `types.bool` option evaluates to true, no error.

**Correction:**

Keep the module, fix the rationale. The two premises that DO hold: (1) `nix eval .#homeConfigurations."deadmade@deadPc".config.gtk.iconTheme` → null and the live ~/.config/gtk-3.0/settings.ini contains only gtk-cursor-theme-name/size, gtk-font-name=Montserrat 12, gtk-theme-name=adw-gtk3 — no icon theme anywhere; (2) stylix hardcodes the light variant (modules/gtk/hm.nix:56-59, `name = "adw-gtk3"`) while both variants exist in /nix/store/xjd3j50qzfvvvkjcc35khqjllnlz9599-adw-gtk3-6.5/share/themes/. Removing the host-level `gtk.enable` is optional tidying, not a prerequisite. Also worth naming as the idiomatic alternative for the icon half: stylix has first-class `stylix.icons.{enable,package,dark,light}` (stylix/icons.nix:47-70), which feeds both the gtk and qt targets — irrelevant here only because both targets are being disabled.

### [UNCERTAIN] Change 4b — papirus-icon-theme.override { color = "bluegrey"; }

**Evidence:** `color` is a real override argument: `lib.functionArgs pkgs.papirus-icon-theme.override` → [color fetchFromGitHub gitUpdater gtk3 hicolor-icon-theme kdePackages lib papirus-folders stdenvNoCC]. package.nix:46 runs `papirus-folders -t $theme -o -C ${color}` inside installPhase. Papirus-Dark exists and inherits breeze-dark+hicolor: /nix/store/553.../share/icons/{Papirus,Papirus-Dark,Papirus-Light,breeze-dark→breeze-icons-6.26.0,hicolor}. What I could NOT verify is that "bluegrey" is a legal papirus-folders colour name — pkgs.papirus-folders has no bin/papirus-folders at its top level so I could not read its colour list.

**Correction:**

This is a build-time hard failure, not a silent one: an unknown colour makes papirus-folders exit non-zero and the derivation fails. Either verify the name first (`papirus-folders -l`) or ship the safe version and defer the folder tint:

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

That also avoids the from-source rebuild of a 247 MB theme that the override forces.

### [WRONG] Change 4c — unflagged fallout: disabling stylix.targets.gtk also kills Flatpak theming

**Evidence:** stylix modules/gtk/hm.nix:23 and :67-108 define `stylix.targets.gtk.flatpakSupport.enable` (default true) which writes ~/.themes/<theme> (a flattened copy of adw-gtk3 with the base16 CSS appended) and ~/.local/share/flatpak/overrides/global with `GTK_THEME=` plus a filesystem grant. Both are live HM symlinks right now: `ls ~/.themes` → adw-gtk3 → /nix/store/gx81c3j9gw0rm3rj508ypcypvgjxdqld-home-manager-files/.themes/adw-gtk3, and ~/.local/share/flatpak/overrides/global points into the same generation. The repo has modules/home-manager/flatpak. The design's `gtk.enable = false` silently removes both and never mentions it.

**Correction:**

Call it out in the plan and decide deliberately. Flatpak apps will still read ~/.config/gtk-3.0/gtk.css (which Noctalia will own), so the colours survive; what is lost is the forced GTK_THEME and the ~/.themes grant. If you want to keep the override, re-declare it in desktop/gtk.nix rather than relying on the stylix target:

    services.flatpak.overrides.global.Environment.GTK_THEME = "adw-gtk3-dark";

Second unflagged consequence: with `gtk.gtk4.theme = null`, home-manager stops writing the `@import url("file://<adw-gtk3>/share/themes/.../gtk-4.0/gtk.css")` line (HM modules/misc/gtk/gtk4.nix:156-167), so GTK4/libadwaita apps get stock Adwaita shape plus Noctalia colour variables and no adw-gtk3 shape at all. That is probably what you want, but say so.

### [CONFIRMED] Change 5 — Qt root-cause diagnosis in modules/nixos/desktop/appearance.nix

**Evidence:** stylix modules/qt/hm.nix:15-19 sets the HM qt target's autoEnable to literally `nixosConfig != null`; `nix eval .#homeConfigurations."deadmade@deadPc".config.stylix.targets.qt.enable` → false, while `nix eval .#nixosConfigurations.deadPc.config.qt` → enable true / platformTheme "qt5ct" (stylix modules/qt/nixos.nix:38-46). Live: QT_QPA_PLATFORMTHEME=qt5ct, ~/.config/qt5ct does not exist, ~/.config/qt6ct/colors/ exists but is EMPTY. The env-var-with-no-writer story is exactly right. Packages exist: kdePackages.qt6ct → qt6ct-0.11, libsForQt5.qt5ct → qt5ct-1.9. No other definition of QT_QPA_PLATFORMTHEME anywhere in modules/ hosts/ profiles/ (grep, no hits).

**Correction:**

Two things to fix in the snippet. (a) `programs.dconf.enable = true;` is dead weight — see the next verdict. (b) `environment.variables` does not reach systemd user units; if you ever want a Qt app started by a user unit themed, prefer the home-manager route (next verdict), which sets both home.sessionVariables and systemd.user.sessionVariables.

### [WRONG] Change 5b — "no dconf GSettings backend is installed today"

**Evidence:** `nix eval .#nixosConfigurations.deadPc.config.programs.dconf.enable` → true. `command -v dconf` → /run/current-system/sw/bin/dconf. `nix eval .#nixosConfigurations.deadPc.config.environment.sessionVariables` contains GIO_EXTRA_MODULES = ".../dconf-0.49.0-lib/lib/gio/modules" and the live shell has it too. The designer looked in /run/current-system/sw/lib/gio/modules — dconf's GIO module is registered through GIO_EXTRA_MODULES, not by being symlinked into the system profile, so its absence there proves nothing. The derived claim that "every GSettings write on this system currently goes somewhere GTK will not read it back from" is false.

**Correction:**

Delete `programs.dconf.enable = true;` and the whole comment block above it from appearance.nix. The one true sub-claim is that `gsettings` (glib bin) is not on PATH — but Noctalia's gtk apply.sh handles that: assets/templates/gtk/apply.sh:61-103 falls through to `dconf write /org/gnome/desktop/interface/{gtk-theme,color-scheme}` when gsettings is missing, and dconf IS present. Note this also means HM's `dconf.settings."org/gnome/desktop/interface"` (HM modules/misc/gtk/gtk3.nix:148-168, which writes gtk-theme/icon-theme/color-scheme) and Noctalia's apply.sh write the same keys — same values (adw-gtk3-dark / prefer-dark) so no visible fight, but worth knowing.

### [WRONG] Change 6 — modules/home-manager/desktop/qt.nix, premise "home-manager has no qt5ctSettings/qt6ctSettings"

**Evidence:** `nix eval .#homeConfigurations."deadmade@deadPc".options.qt --apply builtins.attrNames` → [ "enable" "kde" "kvantum" "platformTheme" "qt5ctSettings" "qt6ctSettings" "style" "useGtkTheme" ]. The options exist in the pinned HM (/nix/store/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules/misc/qt.nix:293 genAttrs' ["qt5ct" "qt6ct"] → "<n>Settings"), and lines 429-441 write xdg.configFile."qt6ct/qt6ct.conf" from them via pkgs.formats.ini. So the design's grep was wrong, and the derived claim that stylix's HM qt target "would actually fail to evaluate here if it were enabled" is also wrong.

**Correction:**

Use the HM module instead of hand-writing INI. It generates the same file, installs the platform-theme packages, and — unlike `environment.variables` in change 5 — sets QT_QPA_PLATFORMTHEME in BOTH home.sessionVariables and systemd.user.sessionVariables (qt.nix:400-410):

    { config, pkgs, ... }: let
      inherit (config.stylix) fonts;
      qtct = dir: {
        Appearance = {
          style = "Fusion";
          custom_palette = true;
          color_scheme_path = "${config.xdg.configHome}/${dir}/colors/noctalia.conf";
          icon_theme = config.gtk.iconTheme.name;
          standard_dialogs = "xdgdesktopportal";
        };
        Fonts = {
          general = ''"${fonts.sansSerif.name},${toString fonts.sizes.applications}"'';
          fixed = ''"${fonts.monospace.name},${toString fonts.sizes.terminal}"'';
        };
      };
    in {
      qt = {
        enable = true;
        # styleNames has no "qt6ct" key, so QT_QPA_PLATFORMTHEME becomes the
        # literal string (HM modules/misc/qt.nix:356-357); platformPackages has
        # no "qt6ct" key either, so name the package explicitly.
        platformTheme = { name = "qt6ct"; package = pkgs.qt6Packages.qt6ct; };
        qt6ctSettings = qtct "qt6ct";
        qt5ctSettings = qtct "qt5ct";
      };
    }

If you take this route, DROP `environment.variables.QT_QPA_PLATFORMTHEME` from appearance.nix (two writers) and keep only `stylix.targets.qt.enable = false` on the NixOS side plus the qt5ct package for Qt5 holdouts. Remaining genuinely-unverified bits, unchanged by this correction: that qt5ct 1.9 accepts `standard_dialogs=xdgdesktopportal` (the enum in stylix modules/qt/hm.nix:43-49 is sourced from qt6ct), and that qt6ct accepts `style=Fusion` with that capitalisation. The pre-existing real 207-byte ~/.config/qt6ct/qt6ct.conf will still collide on first switch — confirmed, it is a regular file, not a symlink.

### [CONFIRMED] Change 7 — stylix.targets.{gtk,qt,ghostty}.enable = false

**Evidence:** Both failure modes are real and I read the code. GTK: assets/templates/gtk/apply.sh:41-51 — on a symlink whose readlink -f target is not writable it does `rm "$gtk_css"` and writes a plain file; ~/.config/gtk-3.0/gtk.css is exactly such a symlink today (→ /nix/store/gx81.../home-manager-files/...). Ghostty: assets/templates/ghostty/apply.sh:8-14 `write_if_changed` does `cat "$tmp" >"$target"` under `set -euo pipefail` at line 2, and ~/.config/ghostty/config is a store symlink. The no-op branch at line 20 is `grep -qE '^theme\s*=\s*noctalia$'`, and HM emits exactly that shape (live config has `theme = stylix`). HM only writes gtk-3.0/gtk.css when extraCss is non-empty (HM modules/misc/gtk/gtk3.nix:139), so with the target off Noctalia genuinely owns it.

**Correction:**

`qt.enable = false;` in the HM stylix targets block is a no-op — `nix eval .#homeConfigurations."deadmade@deadPc".config.stylix.targets.qt.enable` is already false. Harmless to keep, but reword the comment so nobody thinks it is load-bearing; the qt target that IS on is the NixOS one.

### [CONFIRMED] Change 8 — Noctalia shell.font_family and builtin_ids

**Evidence:** `noctalia config export full` line 437: `font_family = "sans-serif"` under [shell]; src/config/schema/config_schema.cpp:1546-1557 parses it as a trimmed free string falling back to "sans-serif" — so naming a family is legal. All six proposed ids appear in `noctalia theme --list-templates` (gtk3, gtk4, qt, kcolorscheme, ghostty, btop) and in assets/templates/builtin.toml:123/132/144/117/93/180. Stylix's noctalia-shell target is indeed a no-op: modules/noctalia-shell/hm.nix:8 guards everything on `options.programs ? noctalia-shell` and this repo uses `programs.noctalia` (noctalia.nix:21).

**Correction:**

The snippet carries `launcher_placement = "centered"` forward verbatim, and that is one of the three dead values the brief warned about. `noctalia config export full` prints: config.toml:70:22: shell.panel.launcher_placement: unknown value "centered". The enum is defined at src/config/config_types.h:881-883 as exactly {"attached", "floating"} (kPanelPlacements), default Floating (:971). Since you are editing that block anyway, either drop the key or write:

        panel.launcher_placement = "floating";   # or "attached"

The same command also confirms `calendar.cards: unknown setting` (config.toml:27) is still live and still discarded.

### [WRONG] Change 8b / Change 9 — adding "btop" to builtin_ids introduces a NEW read-only-symlink breakage

**Evidence:** The design names this failure class in prose ("the same `cat >` pattern appears in the btop and starship apply.sh scripts") and then enables the btop template anyway without disabling the stylix target. Verified: `nix eval .#homeConfigurations."deadmade@deadPc".config.stylix.targets.btop.enable` → true; ~/.config/btop/btop.conf is a store symlink into home-manager-files; assets/templates/btop/apply.sh:11-16 is the identical `cat "$tmp" >"$target"` under `set -euo pipefail`. First theme apply after this lands will abort that template with a permission error.

**Correction:**

Do not disable the whole btop target — just force the one key so apply.sh takes its no-op branch (it greps `^color_theme\s*=\s*"noctalia"`, and HM already emits the quoted form: live btop.conf line 1 is `color_theme = "stylix"`). In modules/home-manager/core/btop.nix:

    programs.btop.settings.color_theme = lib.mkForce "noctalia";

(add `lib` to the module args). Stylix keeps writing ~/.config/btop/themes/stylix.theme, Noctalia writes themes/noctalia.theme, both coexist.

### [CONFIRMED] Change 9 — ghostty.nix option names and enum values

**Evidence:** Every key and value checked against the real binary: /nix/store/444h3sfs9fk7fi8hif6wgg11rkc24vjd-ghostty-1.3.1/bin/ghostty +show-config --default --docs shows window-padding-x=2, window-padding-y=2, window-padding-balance=false, window-padding-color=background, window-decoration=auto, gtk-toolbar-style=raised (valid: flat|raised|raised-border), gtk-titlebar-style=native ("Available values are `native` and `tabs`"), gtk-wide-tabs=true, cursor-style=block, cursor-style-blink, mouse-hide-while-typing=false, background-blur=false, theme, font-family, font-size, background-opacity. The duplicate is real: live ~/.config/ghostty/config contains `font-size = 12` then `font-size = 11` on consecutive lines, plus `background-blur = 10` and `theme = stylix`.

### [WRONG] Change 9b — FATAL: the rewritten ghostty.nix breaks deadWsl and `nix flake check`

**Evidence:** profiles/home-manager/wsl.nix imports `builtins.attrValues outputs.homeManagerModules.terminal`, so modules/home-manager/terminal/ghostty.nix is evaluated for homeConfigurations."deadmade@deadWsl". That configuration does not import modules/home-manager/core/stylix.nix (wsl.nix cherry-picks only coding.direnv and core.{aliases,homeConfig,nixConfig}), and the stylix option tree therefore does not exist there. Proof: `nix eval .#homeConfigurations --apply 'h: builtins.tryEval (h."deadmade@deadWsl".config.stylix.fonts.sansSerif.name)'` → error: attribute 'stylix' missing. The proposed file references config.stylix.fonts.monospace.name, .emoji.name, .sizes.terminal and config.stylix.opacity.terminal — four hard eval failures on deadWsl.

**Correction:**

Do not pull stylix into a module that the WSL profile imports. The minimal fix that solves both real ghostty defects without any stylix dependency is to LEAVE stylix.targets.ghostty enabled and override only the two offending keys:

    { pkgs, lib, ... }: {
      programs.ghostty = {
        enable = true;
        package = pkgs.unstable.ghostty;
        enableZshIntegration = true;
        settings = {
          command = "tmux new-session -A -s main";
          term = "xterm-256color";
          # font-size/font-family/background-opacity come from stylix's ghostty
          # target (modules/ghostty/hm.nix:7-28); do not restate them.
          # Forcing the theme name makes noctalia's apply.sh take its no-op
          # branch instead of `cat >`-ing this read-only store symlink.
          theme = lib.mkForce "noctalia";
          window-padding-x = 12;
          window-padding-y = 8;
          window-padding-balance = true;
          window-padding-color = "extend";
          window-decoration = "client";
          gtk-titlebar-style = "tabs";
          gtk-toolbar-style = "flat";
          gtk-wide-tabs = false;
          window-new-tab-position = "end";
          cursor-style = "block";
          cursor-style-blink = false;
          mouse-hide-while-typing = true;
          keybind = [ ... ];   # unchanged
        };
      };
    }

This drops `background-blur` and the duplicate `font-size`, keeps one source of truth for fonts/opacity, and needs no `stylix.targets.ghostty.enable = false` at all. If you insist on owning fonts here, the alternative is to add `outputs.homeManagerModules.core.stylix` to profiles/home-manager/wsl.nix — but that drags the whole theme closure onto WSL for no benefit. Same discipline applies to `home.packages = [ jetbrains-mono ]`: dropping it is safe and unrelated to stylix.

### [CONFIRMED] Change 10 — cursor.size 25 → 24

**Evidence:** Parsed the Xcursor TOC of /nix/store/0aapb6vy86v1iwkqx9fpykmfjg5dri0m-bibata-cursors-2.0.7/share/icons/Bibata-Modern-Ice/cursors/left_ptr (magic b'Xcur', 14 TOC entries, chunk type 0xfffd0002): nominal sizes [16, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72, 80, 88, 96]. No 25. Live env XCURSOR_SIZE=25. Bibata-Modern-Ice is a real theme directory in that package (Modern/Original x Amber/Classic/Ice, plus -Right variants).

### [UNCERTAIN] Change 11 — fontconfig tabular-figures rule in modules/home-manager/desktop/fonts.nix

**Evidence:** No file collision: ~/.config/fontconfig does not exist at all right now, and HM's own fontconfig writer uses a different basename (10-hm-fonts.conf), so xdg.configFile."fontconfig/conf.d/52-ui-tabular-figures.conf" lands cleanly. `fc-match --format '%{fontfeatures}\n' sans-serif` returns an empty value without erroring on fontconfig 2.17.1, which is consistent with the property being recognised but unset. What remains unproven is the part that matters: that Qt 6's QFontconfigDatabase forwards FC_FONT_FEATURES into HarfBuzz shaping, and Noctalia is Qt. The designer says so themselves.

**Correction:**

Keep it, but plan it as a measure-then-decide step rather than a fix: land it, watch the bar clock, and only then decide between keeping Adwaita Sans and swapping to pkgs.ibm-plex / "IBM Plex Sans" (verified present: ibm-plex-1.1.0). Do not present it as settled. Also note that a `target="font"` family test only matches the resolved font's own family — it will not catch the case where something asks for the generic "sans-serif" and gets a fallback.

### [CONFIRMED] Change 12 — delete the kitty module and drop system-wide kitty

**Evidence:** modules/home-manager/terminal/kitty/default.nix: `home.file.".config/kitty/themes"` and `home.packages = [ jetbrains-mono ]` are both outside the programs.kitty attrset, so they ship regardless of `enable = false`. kitty is in modules/nixos/core/packages.nix systemPackages (the list is curl git btop wl-clipboard superfile kitty); `readlink -f /run/current-system/sw/bin/kitty` → /nix/store/06y20vwgj8c3acvjzkih7a68774hrpzp-kitty-0.48.2. Live ~/.config/kitty holds a real kitty.conf, a kitty.conf.bak and current-theme.conf → themes/noctalia.conf, confirming the Noctalia kitty template has been maintaining a hand-made config. `vars.terminal` is dead: flake/modules/constants.nix:13 is the only occurrence in the repo. Deleting the directory is the whole HM-side change — flake/lib/registry.nix auto-discovers, and both desktop-dev.nix and wsl.nix import `builtins.attrValues outputs.homeManagerModules.terminal`.

**Correction:**

One caveat the design does not draw out: wsl.nix also imports the terminal domain wholesale, so deadWsl loses the kitty HM module too (harmless) — but removing kitty from core/packages.nix removes the binary and terminfo from deadWsl, deadServer and deadPi as well. If anything SSHes into those with `kitty +kitten ssh`, keep `kitty.terminfo` (a separate output) in systemPackages.

### [CONFIRMED] Change 13 — wire modules/home-manager/desktop/ into desktop-dev.nix

**Evidence:** flake/lib/registry.nix: a directory without default.nix recurses into a nested registry, a .nix file becomes attr name minus .nix — so modules/home-manager/desktop/{gtk,qt,fonts}.nix becomes outputs.homeManagerModules.desktop.{gtk,qt,fonts}, built by flake/modules/exports.nix (`homeManagerModules = registry ../../modules/home-manager`). modules/nixos/desktop/ exists as the precedent. profiles/home-manager/wsl.nix cherry-picks and does NOT attrValues a `desktop` domain, so WSL is unaffected — correct. The git-add-before-rebuild warning is correct for flakes.

**Correction:**

Only the stated *requirement* to delete `gtk = { enable = true; };` from hosts/deadPc/home.nix is wrong (types.bool merges equal definitions — verified). Do it as cleanup if you like, not as a prerequisite. Also add the NixOS half explicitly to the plan: `outputs.nixosModules.desktop.appearance` must be added to profiles/nixos/desktop.nix, whose import list currently ends at desktop.bluetooth, and modules/nixos/desktop/ has no `appearance.nix` today so there is no name collision.

## Proposed changes

### 1. (high) Replace Montserrat with Adwaita Sans as the UI face, fix serif, declare emoji

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Measured with fontTools/ttx on the actual store paths. Montserrat-Regular: unitsPerEm 1000, sxHeight 526, sCapHeight 700, GSUB has no `calt` at all — it is a geometric display face with no contextual shaping and very wide advances. Adwaita Sans-Regular: unitsPerEm 2048, sxHeight 1118, sCapHeight 1490 — byte-identical metrics and an identical GSUB feature set to InterVariable.ttf (aalt calt case ccmp cv01–cv14 dlig dnom frac locl numr ordn pnum salt sinf ss01–ss08 subs sups tnum zero), i.e. it *is* GNOME's Inter fork. The decisive number is the pairing: Adwaita Sans x-height/em = 1118/2048 = 0.546; JetBrainsMonoNerdFontMono-Regular x-height/em = 550/1000 = 0.550. Those are 0.7% apart, so UI text and terminal text have visually identical letter size at one nominal point size. Montserrat is 0.526 (-4.4%) and Geist 0.530, IBM Plex Sans 0.516 (-6.2%), Public Sans 0.517, Figtree 0.500. Adwaita Sans is also the typeface adw-gtk3 — the GTK theme this desktop already uses (`gtk-theme-name=adw-gtk3` in the live settings.ini) — was drawn for, and the package is 7.4 MB and carries a real variable font (fc-scan reports `Adwaita Sans||True`) so `bar.default.font_weight = 500` resolves to a designed Medium rather than a synthesised one. Serif currently also resolves to Montserrat (`fc-match serif` → Montserrat-Regular.otf), which is simply wrong; `source-serif` 4.005 registers family "Source Serif 4", is 29 MB, and is a text serif with metrics close enough to a grotesque to sit under Adwaita Sans. Emoji is currently undeclared and only works by falling through to Stylix's own default — declaring it removes the accident. `outfit` is NOT in nixpkgs (stable or unstable); `noto-fonts-emoji` no longer exists, the attribute is `noto-fonts-color-emoji`. TABULAR FIGURES CAVEAT: every candidate I measured is proportional by default — Adwaita Sans/Inter digit advances are one=833, seven=1159, four=1323 — so the bar clock will shift width as digits change unless `tnum` is forced (see the fontconfig change). The only two candidates that are tabular *by default* are Roboto (all digits 1151) and IBM Plex Sans (all digits 600); if the fontconfig route does not take under Qt, `IBM Plex Sans` is the drop-in swap at the cost of the 6.2% x-height mismatch with JetBrains Mono.

**Verified against:** `nix eval` on .#nixosConfigurations.deadPc.pkgs.{adwaita-fonts,source-serif,noto-fonts-color-emoji,inter,geist-font,ibm-plex,figtree,rubik,lexend,public-sans,roboto,outfit}; `ttx -t GSUB -t OS/2 -t head -t hmtx` on /nix/store/b8gbdhi666cj91b9n83dac47627gla2i-adwaita-fonts-50.0, /nix/store/kkbjg7a8l7v24lgpgq9w69824nm84sw2-inter-4.1, /nix/store/r1f49bnv17nbwjsrwp0z169cw0c6xvwl-montserrat-9.000, /nix/store/pdj6gnskz4br36rh92a3kqf4r7pbsl9k-nerd-fonts-jetbrains-mono-3.4.0+2.304; stylix/fonts.nix in /nix/store/95awhm3a9mclvmv956gfdgk4r7z9w88s-source (fonts.sizes option definition and defaults)

**Risk:** `pkgs.adwaita-fonts` also ships Adwaita Mono; harmless but it lands in the font list. Changing sansSerif changes `fc-match sans-serif` globally, so any app that asked for the generic family (including Noctalia today) shifts at once. Source Serif 4 has Caption/Display optical-size subfamilies which fontconfig enumerates separately — the plain "Source Serif 4" family is the text cut and is what will match.

```nix
    cursor.package = pkgs.unstable.bibata-cursors;
    cursor.name = "Bibata-Modern-Ice";
    cursor.size = 24;

    fonts = {
      monospace = {
        package = pkgs.unstable.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      # Adwaita Sans is GNOME's Inter fork: identical upem/x-height/cap-height
      # and an identical GSUB feature set to InterVariable.ttf (verified with
      # ttx). Its x-height/em is 0.546 against JetBrains Mono Nerd Font Mono's
      # 0.550, so UI text and terminal text match optically at one pt size.
      # It is also the face adw-gtk3 -- the GTK theme used here -- was drawn for.
      sansSerif = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      # serif previously pointed at Montserrat, so `fc-match serif` returned a
      # geometric sans. Source Serif 4 is an actual text serif.
      serif = {
        package = pkgs.source-serif;
        name = "Source Serif 4";
      };
      # Was implicit (Stylix's own default). Declared so it is visible.
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };

      # 1080p at scale 1 on 27" (81.6 PPI) and 24.5" (89.9 PPI) panels. A
      # nominal 11pt is 11 * 96/72 = 14.67 px, which subtends 12.9 real points
      # on the 27" HPs and 11.8 on the Acer -- already generous. The old
      # Montserrat 12 rendered at 14.1 real points there, which is why app UI
      # reads oversized. terminal = 11 makes Stylix agree with ghostty.nix
      # instead of emitting a second, losing `font-size = 12`.
      sizes = {
        applications = 11;
        terminal = 11;
        desktop = 10;
        popups = 10;
      };
    };
```

### 2. (high) Mirror the font/cursor block into the NixOS Stylix module

**File:** `modules/nixos/desktop/stylix.nix`

**Rationale:** The file's own header comment in the HM copy says the two must be kept in sync, and they are two independent definitions because home-manager runs standalone here (flake.homeConfigurations), so `homeManagerIntegration.followSystem` never fires. The NixOS copy is what feeds `fonts.packages`, the console, GRUB/plymouth if ever enabled, and — critically — `config.stylix.fonts.packages`, which the next change consumes. Leaving it on Montserrat means `fc-match sans-serif` at the system level still resolves to Montserrat for anything launched outside the user session (greetd/tuigreet, systemd system units).

**Verified against:** modules/nixos/desktop/stylix.nix (the `lib.mkDefault` wrapper and the in-file sync comment in modules/home-manager/core/stylix.nix); stylix/fonts.nix `stylix.fonts.packages` readOnly option

**Risk:** The whole `stylix` attrset in this file is wrapped in a single `lib.mkDefault { ... }`, which applies default priority to the attrset as one definition rather than per-key. That is pre-existing and not something this change needs to touch, but be aware that any host-level `stylix.fonts` override interacts with it as a whole-attrset override, not a merge.

```nix
    cursor.package = pkgs.unstable.bibata-cursors;
    cursor.name = "Bibata-Modern-Ice";
    cursor.size = 24;
    fonts = {
      monospace = {
        package = pkgs.unstable.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      serif = {
        package = pkgs.source-serif;
        name = "Source Serif 4";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        terminal = 11;
        desktop = 10;
        popups = 10;
      };
    };
```

### 3. (medium) Delete modules/nixos/core/themes.nix; install Stylix's resolved font set from the desktop module

**File:** `modules/nixos/desktop/stylix.nix`

**Rationale:** `modules/nixos/core/themes.nix` installs `pkgs.nerd-fonts.jetbrains-mono` (stable 26.05, nerd-fonts-jetbrains-mono-3.4.0+2.304) while Stylix installs `pkgs.unstable.nerd-fonts.jetbrains-mono` (3.5.0+2.304) — two store paths of the same family, both in the fontconfig path. That is exactly how you get `fc-list` showing duplicate families and non-deterministic matching. Stylix already computes the correct set: `stylix.fonts.packages` is a readOnly option holding [monospace, sansSerif, serif, emoji] packages. Feeding `fonts.packages` from it makes the system font set derive from the same four declarations by construction. themes.nix cannot simply be rewritten in place because it lives in `modules/nixos/core/`, which `profiles/nixos/core.nix` imports wholesale via `builtins.attrValues` onto deadServer and deadPi — hosts that never import the Stylix module, so `config.stylix` would not exist and evaluation would fail. Deleting the file is safe: the registry auto-discovers, nothing references `outputs.nixosModules.core.themes` by name. This also resolves the kitty naming mismatch by construction — the kitty module asked for "JetBrainsMono Nerd Font" while Stylix uses "JetBrainsMono Nerd Font Mono", and both families exist in fc-list today; the kitty module is being deleted anyway.

**Verified against:** modules/nixos/core/themes.nix; `nix eval` showing nerd-fonts.jetbrains-mono = 3.4.0+2.304 (stable) vs unstable.nerd-fonts.jetbrains-mono = 3.5.0+2.304; profiles/nixos/core.nix using builtins.attrValues; flake/lib/registry.nix; `fc-list : family` showing both JetBrainsMono Nerd Font and JetBrainsMono Nerd Font Mono installed

**Risk:** `fonts.packages` here is an unconditional definition while the `stylix` block is `lib.mkDefault`-wrapped; if a host ever disables Stylix this line still evaluates `config.stylix.fonts.packages`, which is fine (the option is defined by the module import, not by `stylix.enable`). Only hosts importing `nixosModules.desktop.stylix` get fonts now — deadServer/deadPi lose `nerd-fonts.jetbrains-mono` system-wide, which is almost certainly correct but is a behaviour change for console rendering on those hosts.

```nix
# modules/nixos/desktop/stylix.nix, at the top level (outside the mkDefault block)

  # Single source of truth for system fonts. Previously
  # modules/nixos/core/themes.nix installed pkgs.nerd-fonts.jetbrains-mono
  # (stable, 3.4.0) while Stylix installed pkgs.unstable.nerd-fonts.jetbrains-mono
  # (3.5.0) -- two store paths of the same family in the fontconfig path.
  # stylix.fonts.packages is the readOnly [monospace serif sansSerif emoji] set.
  fonts.packages = config.stylix.fonts.packages;

# ...and add `config` to the module argument list:
#   { pkgs, lib, config, inputs, ... }:

# then: git rm modules/nixos/core/themes.nix
```

### 4. (high) New modules/home-manager/desktop/gtk.nix — icon theme, adw-gtk3-dark, and the fix for deadConvertible having no GTK config at all

**File:** `modules/home-manager/desktop/gtk.nix`

**Rationale:** Three separate defects collapse into one module. (1) No `gtk-icon-theme-name` is written anywhere — the live ~/.config/gtk-3.0/settings.ini contains only cursor, font and theme keys. (2) `gtk.enable = true` is set in hosts/deadPc/home.nix only, so on deadConvertible the HM gtk module never runs and *no* settings.ini is written at all, despite Stylix's `home.pointerCursor.gtk.enable = true` setting `gtk.cursorTheme`. (3) Stylix sets `gtk.theme.name = "adw-gtk3"` — the LIGHT variant — on a polarity=dark desktop; adw-gtk3 6.5 ships both `adw-gtk3` and `adw-gtk3-dark` and Noctalia's own gtk/apply.sh explicitly wants `adw-gtk3-dark` for dark mode. Icon theme choice: Papirus-Dark. `papirus-icon-theme` 20250501 is a 247 MB closure whose Papirus-Dark/index.theme declares `Inherits=breeze-dark,hicolor`, i.e. it ships the full breeze-dark symbolic set as fallback — with legcord, protonmail-desktop, obsidian, signal-desktop, spotify, okular, nautilus, vscode, jetbrains, steam and heroic in this package set, catalogue coverage is the only property that actually decides whether the launcher and taskbar look finished. Tela-circle, Colloid, Reversal, Qogir and Fluent all have materially smaller app catalogues and fall through to hicolor more often; MoreWaita only patches GNOME's gaps and needs adwaita-icon-theme underneath. Against a wallpaper-recolouring desktop the argument for Papirus is that its per-app icons are already saturated brand colours that read against any surface, and the one element that *is* theme-coloured — folders — can be pinned at build time via `.override { color = "..."; }` (the derivation takes a `color` argument, verified via `__functionArgs`). `bluegrey` is the neutral that stays legible whether Material You lands on a warm or cool wallpaper. Deliberately NOT setting `gtk.gtk4.theme`: HM writes ~/.config/gtk-4.0/gtk.css whenever `gtk.gtk4.theme != null` (gtk4.nix line 156-167), which would collide with Noctalia's gtk4 template.

**Verified against:** ~/.config/gtk-3.0/settings.ini (live, no gtk-icon-theme-name); hosts/deadPc/home.nix vs hosts/deadConvertible/home.nix; /nix/store/xjd3j50qzfvvvkjcc35khqjllnlz9599-adw-gtk3-6.5/share/themes/ listing both variants; assets/templates/gtk/apply.sh in the Noctalia source (target_theme=adw-gtk3-dark branch and theme_exists()); /nix/store/553nci1npfs7rsvq8pc29ki7bvq4si1k-papirus-icon-theme-20250501/share/icons/Papirus-Dark/index.theme (Inherits=breeze-dark,hicolor) and `du -sh` = 247M; `nix eval --apply 'p: builtins.attrNames (builtins.functionArgs p.override)'` showing color:true; home-manager modules/misc/gtk.nix + gtk/gtk3.nix + gtk/gtk4.nix in /nix/store/v573js9566ja0r1r1s8pw6y06z2wq5k4-source; stylix/hm/cursor.nix

**Risk:** 247 MB closure for the icon theme, plus a full rebuild of papirus-icon-theme because `.override { color = ... }` defeats the binary cache (the derivation runs papirus-folders at build time). If the rebuild time is unacceptable, drop the `.override` and take Papirus's stock blue folders. Second risk: `gtk.gtk4.theme = null` is my reading of gtk4.nix's conditional — if the option's default already resolves to null the line is a no-op, and if a future HM makes gtk4.theme inherit `gtk.theme` the explicit null is what keeps gtk-4.0/gtk.css unmanaged.

```nix
{
  config,
  pkgs,
  ...
}: {
  gtk = {
    enable = true;

    # Stylix stays the font authority; only the *colour* authority moves to
    # Noctalia. stylix.targets.gtk is disabled, so gtk.font must be set here.
    font = {
      inherit (config.stylix.fonts.sansSerif) package name;
      size = config.stylix.fonts.sizes.applications;
    };

    # adw-gtk3 6.5 ships both `adw-gtk3` and `adw-gtk3-dark`; Stylix picked the
    # light one on a polarity=dark desktop. Noctalia's gtk/apply.sh also looks
    # for `adw-gtk3-dark` when mode=dark, so this makes the two agree.
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };

    # Deliberately left unset: HM writes gtk-4.0/gtk.css whenever gtk4.theme is
    # non-null, which would collide with Noctalia's gtk4 template.
    gtk4.theme = null;

    # Papirus-Dark inherits breeze-dark + hicolor, so third-party apps that ship
    # no icon still land on a symbolic rather than the generic executable glyph.
    # `color` pins the folder accent at build time -- bluegrey is the neutral
    # that survives whatever Material You extracts from the current wallpaper.
    iconTheme = {
      package = pkgs.papirus-icon-theme.override {color = "bluegrey";};
      name = "Papirus-Dark";
    };

    # Writes gtk-application-prefer-dark-theme + the gtk4 color-scheme key and
    # mirrors both into dconf org/gnome/desktop/interface.
    colorScheme = "dark";

    # NOT set here: cursorTheme. Stylix's home.pointerCursor has gtk.enable = true
    # and already defines it; a second definition is a conflict, not a merge.
  };
}
```

### 5. (high) Fix Qt: it is broken because QT_QPA_PLATFORMTHEME=qt5ct while only the HM qt target writes qt5ct/qt6ct colours, and that target is disabled on standalone HM

**File:** `modules/nixos/desktop/appearance.nix`

**Rationale:** Root cause, verified end to end. Stylix's NixOS qt target auto-enables and sets `qt.enable = true; qt.platformTheme = "qt5ct"` (`nix eval .#nixosConfigurations.deadPc.config.qt` returns {enable:true, platformTheme:"qt5ct", style:null} and environment.variables.QT_QPA_PLATFORMTHEME = "qt5ct"). But the module that actually *writes* qt5ctSettings/qt6ctSettings is stylix's HM qt target, whose autoEnable expression is literally `nixosConfig != null` — and this repo builds home-manager standalone via flake.homeConfigurations, so nixosConfig IS null and that target never runs. Hence the env var with no writer, and ~/.config/qt5ct/ that does not even exist. Two further facts make `qt5ct` the wrong target regardless: the NixOS qt module's platformTheme enum is `gnome|gtk2|kde|lxqt|qt5ct` — there is no `qt6ct` value, so the NixOS module cannot produce the right variable and must be bypassed; and qt5ct's plugin is Qt5-only (libqt5ct.so lives under lib/qt-5.15.19/plugins/platformthemes), so VLC, Telegram, okular and qBittorrent — all Qt6 now — get no platform theme at all. Noctalia covers both halves: the `qt` builtin template writes to BOTH $XDG_CONFIG_HOME/qt5ct/colors/noctalia.conf and qt6ct/colors/noctalia.conf from one input, and the `kcolorscheme` template writes $XDG_DATA_HOME/color-schemes/noctalia.colors and then runs post_action `kde-color-scheme`, which merges the colour groups into ~/.config/kdeglobals and emits the KDE globals-changed D-Bus signal so running KDE apps repaint live. `programs.dconf.enable` is also missing entirely: /run/current-system/sw/lib/gio/modules/ has no libdconfsettings.so, `gsettings` is not even on PATH, and xfconf's GSettings backend (from programs.xfconf.enable) is the only one registered — so every GSettings write on this system currently goes somewhere GTK will not read it back from.

**Verified against:** `nix eval .#nixosConfigurations.deadPc.config.qt` and `.config.environment.variables.QT_QPA_PLATFORMTHEME`; `nix eval .#nixosConfigurations.deadPc.options.qt.platformTheme.type.description` = 'null or one of "gnome", "gtk2", "kde", "lxqt", "qt5ct"'; modules/qt/hm.nix + modules/qt/nixos.nix in the Stylix source (autoEnable = nixosConfig != null); assets/templates/builtin.toml [templates.qt] dual output_path and [templates.kcolorscheme] post_action; src/theme/kde_color_scheme.cpp applyKdeColorScheme/mergeKdeColorScheme; ls of /run/current-system/sw/lib/gio/modules and /run/current-system/sw/lib/qt-*/plugins/platformthemes; live `ls ~/.config/qt5ct` (absent) and ~/.config/qt6ct/colors (empty)

**Risk:** Setting QT_QPA_PLATFORMTHEME=qt6ct leaves genuinely-Qt5 apps without a platform theme (there is no per-Qt-version env var). The kcolorscheme template covers KDE-Frameworks apps of either generation via kdeglobals, but a plain Qt5 app like VLC 3 falls back to Fusion defaults. The alternative end state — install kdePackages.plasma-integration + libsForQt5.plasma-integration and set QT_QPA_PLATFORMTHEME=kde, so both generations read the kdeglobals that Noctalia already live-updates — is strictly better on coverage but drags in a chunk of KDE and is UNVERIFIED here (I did not check the closure or that plasma-integration works outside a Plasma session). `nix eval .#nixosConfigurations.deadPc.pkgs.kdePackages.qt6ct` is plain qt6ct 0.11 from opencode, NOT the qt6ct-kde fork the Noctalia docs mention, so the qt6ct GUI cannot select a KColorScheme — which is why the config below is written declaratively instead.

```nix
{pkgs, ...}: {
  # Stylix's NixOS qt target sets qt.enable + QT_QPA_PLATFORMTHEME=qt5ct, but
  # the module that writes the qt5ct/qt6ct colour files is its *HM* target,
  # whose autoEnable is `nixosConfig != null` -- false for standalone
  # home-manager. Result: the env var points at a config nobody writes.
  # Take Qt over completely. The NixOS qt module cannot help: its
  # platformTheme enum is gnome|gtk2|kde|lxqt|qt5ct, with no qt6ct value.
  environment.variables.QT_QPA_PLATFORMTHEME = "qt6ct";

  environment.systemPackages = with pkgs; [
    kdePackages.qt6ct # provides lib/qt-6/plugins/platformthemes/libqt6ct.so
    libsForQt5.qt5ct # Qt5 holdouts (VLC 3.x)
  ];

  # No dconf GSettings backend is installed today: /run/current-system/sw/lib/
  # gio/modules has no libdconfsettings.so, `gsettings` is not on PATH, and
  # xfconf's backend is the only one registered. HM's gtk module mirrors the
  # theme/icon/colour-scheme keys into dconf, and Noctalia's gtk apply.sh
  # writes org.gnome.desktop.interface -- neither takes effect without this.
  programs.dconf.enable = true;
}

# and in modules/nixos/desktop/stylix.nix, inside the stylix block:
#   targets.qt.enable = false;
#
# and one line in profiles/nixos/desktop.nix:
#   outputs.nixosModules.desktop.appearance
```

### 6. (high) New modules/home-manager/desktop/qt.nix — declaratively point qt6ct/qt5ct at Noctalia's palette

**File:** `modules/home-manager/desktop/qt.nix`

**Rationale:** Noctalia's qt template writes the colour *scheme* file but nothing selects it; qt6ct only applies a custom palette when `custom_palette=true` and `color_scheme_path` names the file. The pinned home-manager has no `qt.qt5ctSettings`/`qt.qt6ctSettings` options (I grepped the whole modules tree — they exist only in newer HM, which is why Stylix's HM qt target would actually fail to evaluate here if it were enabled), so these must be written as plain config files. Key names verified by `strings` on libqt6ct.so: Appearance, color_scheme_path, custom_palette, icon_theme, standard_dialogs, style, Fonts, general, fixed. `style=Fusion` is the load-bearing choice: Fusion is the only Qt style that renders entirely from QPalette, so a custom palette actually reaches every widget. Breeze and Adwaita-qt hardcode parts of their look and would show a half-themed result; Kvantum would need a Kvantum theme, which Noctalia does not generate. `standard_dialogs=xdgdesktopportal` routes Qt file dialogs through the portal — this repo already enables xdg-desktop-portal-gtk with `common.default = ["hyprland" "gtk"]`, so Qt and GTK apps end up with the same file picker instead of two different ones. Font strings use QFont::fromString's short form (family,pointSize), which is the same form Stylix's own qt target emits.

**Verified against:** `strings` on /nix/store/1ijiiyh4ik9096wbr9yqyhxhn7jcf3nf-qt6ct-0.11/lib/qt-6/plugins/platformthemes/libqt6ct.so; assets/templates/qt/qtct.conf and qt/undo.sh; grep for qt5ctSettings/qt6ctSettings across /nix/store/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules (no hits); modules/qt/hm.nix in the Stylix source for the standardDialogs enum; src/theme/template_engine.cpp inferClientConfigRoot/markMultiClientGatedEntries; modules/nixos/desktop/base.nix xdg.portal config

**Risk:** ~/.config/qt6ct/qt6ct.conf already exists as a real 207-byte file (leftover window geometry from a manual qt6ct run); standalone home-manager has no backupFileExtension set — `home-manager.backupFileExtension = "backup"` in modules/nixos/core/packages.nix applies to the NixOS-embedded HM module, which this repo does not use — so the first switch will hard-error until that file is removed by hand. Making qt6ct.conf a store symlink also means the qt6ct GUI can no longer save; that is the intended tradeoff but it will look like a bug the first time it is hit. I did NOT verify that Noctalia's renderFile creates the qt5ct/colors and qt6ct/colors parent directories when they are absent — if it does not, the directories need to exist first (the qt template is not gated by client-root detection, since inferClientConfigRoot only recognises a `themes` path component, so it will at least attempt both outputs).

```nix
{
  config,
  lib,
  ...
}: let
  inherit (config.stylix) fonts;
  # qt6ct/qt5ct key names verified with `strings` on libqt6ct.so:
  # Appearance / color_scheme_path / custom_palette / icon_theme /
  # standard_dialogs / style, and Fonts / general / fixed.
  mkQtct = dir: ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.xdg.configHome}/${dir}/colors/noctalia.conf
    icon_theme=Papirus-Dark
    standard_dialogs=xdgdesktopportal

    [Fonts]
    general="${fonts.sansSerif.name},${toString fonts.sizes.applications}"
    fixed="${fonts.monospace.name},${toString fonts.sizes.terminal}"
  '';
in {
  # Fusion is the only Qt style that draws entirely from QPalette, so the
  # custom palette Noctalia writes actually reaches every widget. Breeze and
  # adwaita-qt hardcode parts of their appearance.
  xdg.configFile = {
    "qt6ct/qt6ct.conf".text = mkQtct "qt6ct";
    "qt5ct/qt5ct.conf".text = mkQtct "qt5ct";
  };
}
```

### 7. (high) Disable the three Stylix targets that fight Noctalia over the same files

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** Not a preference — two of these are hard failures, both traced in the Noctalia sources. (a) gtk: Stylix's gtk hm target writes `xdg.configFile."gtk-3.0/gtk.css"` and `"gtk-4.0/gtk.css"` as store symlinks. Noctalia's gtk/apply.sh, on finding a symlink whose target is not writable, does `rm "$gtk_css"` and writes a plain file in its place. The next standalone `home-manager switch` then refuses to clobber the now-real file, because backupFileExtension is only set on the NixOS-embedded HM module this repo does not use. (b) ghostty: Noctalia's ghostty/apply.sh does `cat "$tmp" > "$config_file"` on ~/.config/ghostty/config to rewrite `theme = stylix` into `theme = noctalia`; that file is a store symlink, the write goes through to a read-only store path, and `set -euo pipefail` aborts the template. The fix is to declare `theme = "noctalia"` in programs.ghostty.settings so apply.sh's first branch (`grep -qE '^theme\s*=\s*noctalia$'` → no-op) matches and it never writes — but that collides with Stylix's own `settings.theme = "stylix"`, hence disabling the target. (c) qt: covered above. Verified that HM only writes gtk-3.0/gtk.css when `gtk.gtk3.extraCss != ""`, so with the target off and extraCss empty, Noctalia genuinely owns that file.

**Verified against:** assets/templates/gtk/apply.sh (ensure_gtk_css_import, the `rm "$gtk_css"` branch for read-only symlinks) and assets/templates/ghostty/apply.sh (write_if_changed / `cat "$tmp" >"$target"`) in the Noctalia source; modules/gtk/hm.nix in the Stylix source (xdg.configFile gtk.css); home-manager modules/misc/gtk/gtk3.nix line 139 `mkIf (cfg3.extraCss != "")`; modules/nixos/core/packages.nix:25 backupFileExtension scope; live `ls -la ~/.config/gtk-3.0` showing store symlinks

**Risk:** Turning off `stylix.targets.ghostty` also drops the base16 palette definition, so ghostty is entirely dependent on Noctalia's template having run at least once; a fresh machine will show ghostty's stock colours until Noctalia writes ~/.config/ghostty/themes/noctalia. Same shape of risk for GTK. Also worth checking on the first switch: the same `cat >` pattern appears in the btop and starship apply.sh scripts, so any Stylix-managed config those templates touch has the identical failure mode.

```nix
    targets = {
      hyprlock.enable = false;
      starship.enable = false;
      librewolf.profileNames = ["Default"];

      # Colour authority is Noctalia. Its gtk3/gtk4 templates write
      # ~/.config/gtk-{3,4}.0/noctalia.css and rewrite gtk.css to @import it.
      # Stylix's gtk target makes gtk.css a read-only store symlink; Noctalia's
      # apply.sh `rm`s it and writes a plain file, which then breaks the next
      # standalone `home-manager switch` (no backupFileExtension here).
      # Font/theme/icon/colour-scheme move to desktop/gtk.nix.
      gtk.enable = false;

      # Noctalia's `qt` + `kcolorscheme` templates own the Qt palette; the
      # qt5ct/qt6ct .conf files are written by desktop/qt.nix.
      qt.enable = false;

      # Noctalia's ghostty apply.sh does `cat > ~/.config/ghostty/config` to
      # set `theme = noctalia`; against a store symlink that is a permission
      # error and `set -e` kills the template. ghostty.nix declares the theme
      # itself so apply.sh takes its no-op branch. Font family/size and
      # opacity are re-declared there from config.stylix.*.
      ghostty.enable = false;
    };
```

### 8. (high) Wire Noctalia's shell font and the template set

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `shell.font_family` is currently the literal string "sans-serif", so the shell inherits whatever fc-match resolves — today Montserrat, purely by accident. It is a plain string setting (settings_registry.cpp line 547, a TextSetting/SearchPickerSetting with placeholder "sans-serif"), so naming the family is valid and is the only way to set it: Stylix's `noctalia-shell` target is guarded by `lib.optionals (options.programs ? noctalia-shell)` and this repo uses `programs.noctalia` (v5), so it is a confirmed no-op. On templates, the current `builtin_ids = ["kitty"]` is the only one enabled and it themes a terminal that `programs.kitty.enable = false` — meanwhile the gtk3/gtk4/qt/kcolorscheme templates that would actually fix the appearance are all off. All eight ids below appear in `noctalia theme --list-templates` and in assets/templates/builtin.toml. I am deliberately NOT adding `papirus-icons` (see the risk field) and not adding a `bar.default.font_family` override — it exists (settings_registry.cpp line 3143, an optional string falling back to shell.font_family) but a second face in the bar would read as unintentional.

**Verified against:** `noctalia config export full` ([shell] font_family = "sans-serif", [theme.templates] builtin_ids/community_ids/enable_builtin_templates/enable_community_templates); `noctalia theme --list-templates`; assets/templates/builtin.toml catalog; src/shell/settings/settings_registry.cpp:547 and :3143; modules/noctalia-shell/hm.nix in the Stylix source; ~/.local/state/noctalia/community-templates/{papirus-icons,whitesur-icons}/template.toml and the upstream apply.sh + colors fetched from github.com/noctalia-dev/community-templates

**Risk:** THE BRIEF'S PREMISE ABOUT papirus-icons DOES NOT HOLD ON NIXOS, and I recommend against enabling it. Its apply.sh recolour loop is `for variant in Papirus Papirus-Dark Papirus-Light; do [[ -d "/usr/share/icons/$variant" ]] || continue; ...` — /usr/share/icons does not exist here, so every iteration is skipped and nothing is recoloured. Its only other action is `gsettings set org.gnome.desktop.interface icon-theme`, and `gsettings` is not on PATH on this system. Even if both worked it would `cp -r` the whole 247 MB theme into ~/.local/share/icons and mutate it in place with a bundled papirus-folders, i.e. large imperative state outside Nix that would then shadow the Nix-managed theme and fight gtk.iconTheme. whitesur-icons has the identical template.toml shape. If accent-tracking folders are genuinely wanted, the buildable route is a `[theme.templates.user.papirus_icons]` entry pointing at an apply.sh written by Nix that reads from the store path instead of /usr/share — that is real work and I would not do it in this pass. Separately: enabling gtk3/gtk4 makes Noctalia rewrite ~/.config/gtk-{3,4}.0/gtk.css, which is only safe once stylix.targets.gtk.enable = false has landed; sequence those two together.

```nix
      shell = {
        avatar_path = "/home/${vars.username}/.face";
        # Was the literal "sans-serif", so the shell inherited whatever
        # fc-match resolved. Qt resolves this family through fontconfig.
        # Stylix's noctalia-shell target cannot set it: it is guarded by
        # `options.programs ? noctalia-shell`, which is v4 (programs.noctalia-shell);
        # this repo is on v5 (programs.noctalia).
        font_family = "Adwaita Sans";
        panel = {
          launcher_placement = "centered";
        };
      };

      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "stylix";
        templates = {
          enable_builtin_templates = true;
          # kitty was the only one enabled, for a terminal that is not enabled.
          builtin_ids = [
            "gtk3"
            "gtk4"
            "qt"
            "kcolorscheme"
            "ghostty"
            "btop"
          ];
        };
      };
```

### 9. (high) Design ghostty's appearance properly and delete the two dead settings

**File:** `modules/home-manager/terminal/ghostty.nix`

**Rationale:** Two settings in the current file are provably inert. `background-blur = 10`: ghostty's own docs say it is "Supported on macOS and on some Linux desktop environments, including: KDE Plasma" and "All other Linux desktop environments are as of now unsupported" — it works via the KDE blur protocol, which Hyprland does not implement. The blur the user sees comes entirely from Hyprland's `decoration:blur` (live: enabled=true, size=8, passes=1) acting on the 0.8-opacity surface, so this key is doing nothing and should not be reconciled with the motion domain's compositor blur — it should be deleted. `font-size = 11` produces the duplicate the brief describes: the generated config literally contains `font-size = 12` then `font-size = 11`. Padding numbers: JetBrains Mono's advance is 600/1000 = 0.6 em, so at 11pt (14.67 px em) a cell is 8.8 px wide and roughly 17.6 px tall. The stock 2 px padding puts the first glyph column 2 px inside a window with `rounding = 5`, so the corner arc clips it. 12 px horizontal is ~1.4 cell widths — enough to clear the 5 px radius with visible margin — and 8 px vertical is ~0.45 of a line, the classic asymmetric terminal gutter that reads as deliberate rather than as a uniform box. `window-padding-balance = true` matters specifically because this is a tiling WM: every window is an arbitrary size, so without it all leftover sub-cell space piles up on the right and bottom edges. `window-padding-color = extend` matters specifically because the command is `tmux new-session -A -s main`: tmux paints a status bar to the last row, and without `extend` an 8 px strip of plain background sits under it. `gtk-titlebar-style = tabs` merges the tab bar into the titlebar rather than stacking two bars — the config has nine goto_tab keybinds, so tabs are in active use and the vertical saving is real. `gtk-toolbar-style = flat` because `raised` (the default) casts a shadow between the tab bar and the terminal area, which draws an opaque seam straight across a 0.8-opacity blurred surface.

**Verified against:** `ghostty +show-config --default --docs` for every key name and enum: window-padding-x/y/balance/color (background|extend|extend-always), window-decoration (auto|none|client|server), gtk-titlebar-style (native|tabs), gtk-toolbar-style (flat|raised|raised-border), gtk-tabs-location (top|bottom|hidden), cursor-style, cursor-style-blink, mouse-hide-while-typing, and the background-blur platform-support paragraph; live ~/.config/ghostty/config showing the duplicate font-size 12 / 11; `hyprctl getoption decoration:blur:{enabled,size,passes}`; assets/templates/ghostty/apply.sh; ttx hmtx on JetBrainsMonoNerdFontMono-Regular.ttf (advance 600/1000)

**Risk:** `window-decoration = "client"` is a deliberate departure from `auto`: under Hyprland `auto` can negotiate server-side decorations, which Hyprland does not draw, potentially leaving the tab bar with nowhere to live. I have NOT confirmed at runtime that `client` + `gtk-titlebar-style = tabs` renders the way I expect on Hyprland; if the titlebar is unwanted, `window-decoration = "none"` is the alternative, but ghostty's docs state gtk-titlebar settings have no effect in that mode and I did not verify whether tabs survive. Removing `home.packages = [jetbrains-mono]` from this module is safe only once the Nerd Font build is installed system-wide (previous change).

```nix
{
  config,
  pkgs,
  ...
}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.unstable.ghostty;
    enableZshIntegration = true;

    settings = {
      command = "tmux new-session -A -s main";
      term = "xterm-256color";

      # Stylix's ghostty target is off, so family/size/opacity are declared
      # here -- from config.stylix.*, so there is still one source of truth
      # and no second `font-size` line in the generated config.
      font-family = [
        config.stylix.fonts.monospace.name
        config.stylix.fonts.emoji.name
      ];
      font-size = config.stylix.fonts.sizes.terminal;
      background-opacity = config.stylix.opacity.terminal;

      # Declaring this makes Noctalia's ghostty apply.sh take its no-op branch
      # instead of trying to `cat >` the read-only Home Manager symlink.
      # The file it names is written by the `ghostty` builtin template.
      theme = "noctalia";

      # `background-blur` is deleted, not tuned: ghostty implements it via the
      # KDE blur protocol and documents every other Linux DE as unsupported.
      # Under Hyprland the blur comes from decoration:blur acting on this
      # surface's 0.8 opacity.

      # A JetBrains Mono cell at 11pt is 8.8px x ~17.6px. 12px is ~1.4 cells --
      # enough to clear `rounding = 5` so the corner arc stops clipping column
      # one; 8px is ~0.45 of a line.
      window-padding-x = 12;
      window-padding-y = 8;
      # Tiling WM: every window is an arbitrary size, so without this all the
      # sub-cell slack collects on the right and bottom edges.
      window-padding-balance = true;
      # `command` is tmux, whose status bar paints the last row to the edge.
      window-padding-color = "extend";

      window-decoration = "client";
      # Merges the tab bar into the titlebar: one bar instead of two. There are
      # nine goto_tab binds below, so the tab bar is in use.
      gtk-titlebar-style = "tabs";
      # `raised` shadows the tab bar onto the terminal area, which reads as an
      # opaque seam across a translucent blurred surface.
      gtk-toolbar-style = "flat";
      # Wide tabs squeeze nine titles to a few characters each.
      gtk-wide-tabs = false;
      window-new-tab-position = "end";

      cursor-style = "block";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;

      keybind = [
        "ctrl+shift+1=goto_tab:1"
        "ctrl+shift+2=goto_tab:2"
        "ctrl+shift+3=goto_tab:3"
        "ctrl+shift+4=goto_tab:4"
        "ctrl+shift+5=goto_tab:5"
        "ctrl+shift+6=goto_tab:6"
        "ctrl+shift+7=goto_tab:7"
        "ctrl+shift+8=goto_tab:8"
        "ctrl+shift+9=goto_tab:9"
        "ctrl+shift+w=close_tab"
      ];
    };
  };

  # `jetbrains-mono` was installed here alongside the Nerd Font patched build
  # that Stylix installs -- same family, two store paths. Dropped.
}
```

### 10. (medium) Fix the cursor size: 25 is not a size Bibata ships

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** I parsed the Xcursor TOC of /nix/store/0aapb6vy86v1iwkqx9fpykmfjg5dri0m-bibata-cursors-2.0.7/share/icons/Bibata-Modern-Ice/cursors/left_ptr: the theme ships nominal sizes 16, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72, 80, 88, 96. There is no 25. Requesting 25 makes the loader pick the nearest image (24) and scale it up ~4%, which is a resample of a hand-hinted bitmap — visibly soft edges on a pointer that is on screen constantly. 24 is the right value on physical grounds too: at the 81.6 PPI of the 27" HP panels a 24 px cursor subtends 0.29 inch, already larger than it would be on a nominal 96 PPI display; the next native step is 32 if a bigger pointer is wanted for the 5760 px canvas, and nothing between renders sharply. Keep Bibata-Modern-Ice: Ice is the white-fill/black-outline variant, and against dark Material You surfaces a white pointer is the higher-contrast choice — Classic (black fill) would be the wrong call here. The change is to make that deliberate rather than accidental. On hyprcursor: there is no Bibata hyprcursor package in nixpkgs (`nix eval` over pkgs attrNames matching hyprcursor returns exactly ["hyprcursor","rose-pine-hyprcursor"]), so adopting it means building one with hyprcursor-util. At scale 1 with 24 px art already present natively, the SVG-rendering benefit is close to zero. My recommendation is to skip it.

**Verified against:** Python parse of the Xcursor file header/TOC (chunk type 0xfffd0002) in /nix/store/0aapb6vy86v1iwkqx9fpykmfjg5dri0m-bibata-cursors-2.0.7/share/icons/Bibata-Modern-Ice/cursors/left_ptr; `ls` of that package's share/icons showing the Modern/Original x Amber/Classic/Ice variants; `nix eval` over pkgs attrNames filtered on hyprcursor; live env XCURSOR_SIZE=25 / XCURSOR_THEME=Bibata-Modern-Ice; stylix/cursor.nix and stylix/hm/cursor.nix

**Risk:** Stylix's cursor size feeds home.pointerCursor.size, XCURSOR_SIZE, and gtk-cursor-theme-size all at once, so this is a single coherent change — but XCURSOR_SIZE is currently 25 in the live environment and some already-running clients cache it until restart. No hyprcursor means Hyprland keeps using the XCursor path; that is fine at scale 1 but would need revisiting if fractional scaling is ever introduced.

```nix
    # Bibata ships nominal Xcursor sizes 16 20 22 24 28 32 40 48 56 64 72 80
    # 88 96 (parsed from the left_ptr TOC). 25 is not one of them, so the
    # loader picked 24 and rescaled ~4% -- a resampled hinted bitmap on the one
    # element that is always on screen. 24px at the 81.6 PPI of the 27" panels
    # already subtends 0.29"; the next native step up is 32.
    #
    # Ice is the white-fill variant, kept deliberately: highest contrast
    # against the dark Material You surfaces. (Classic is black-fill.)
    cursor.size = 24;
```

### 11. (medium) Force tabular figures for the UI face so the bar clock and sysmon readouts stop shifting

**File:** `modules/home-manager/desktop/fonts.nix`

**Rationale:** Measured digit advances in Adwaita Sans (identical to Inter): one=833, seven=1159, five=1215, two=1249, three=1265, eight=1267, six=nine=1270, zero=1292, four=1323 out of 2048 upem. A clock going 11:11 to 12:44 changes width by roughly 1.9 em-thousandths per digit pair, which on a bar where the clock sits inside the `end` group shifts every widget to its right. Both Adwaita Sans and Inter carry `tnum` (and `zero`) in GSUB — the feature is there, it is just not on by default. fontconfig 2.17.1 is what this system runs and supports the `fontfeatures` property, and Pango (so every GTK app) honours FC_FONT_FEATURES. Noctalia itself never sets font features — I grepped its whole src/ tree for tnum/setFeature/QFont::Feature and there are no hits, so fontconfig is the only lever. Scoping the rule to the one family avoids turning tabular figures on for body text, where proportional figures are correct.

**Verified against:** `ttx -t hmtx` digit advances for AdwaitaSans-Regular.ttf, InterVariable.ttf, Geist-Regular.ttf, Montserrat-Regular.otf, Roboto-Regular.ttf, IBMPlexSans-Regular.ttf, Rubik[wght].ttf, PublicSans-Regular.ttf, Figtree-Regular.ttf; `ttx -t GSUB` confirming tnum+zero in Adwaita Sans/Inter; `fc-match --format "%{fontfeatures}"` succeeding and `fontconfig version 2.17.1`; grep -riI 'tnum|setFeature|FontFeature|tabular' over the Noctalia src tree (no hits)

**Risk:** UNCERTAIN FOR QT, WHICH IS THE CASE THAT ACTUALLY MATTERS HERE. I could not confirm that Qt 6's QFontconfigDatabase reads FC_FONT_FEATURES and applies it to shaping; a web search turned up nothing definitive and I did not read qtbase source. GTK/Pango support is well established. If the Noctalia bar clock still jitters after this lands, the deterministic fallback is to swap the UI face to IBM Plex Sans, whose digits are uniformly 600/1000 with no tnum feature needed at all — at the cost of an x-height/em of 0.516 against JetBrains Mono's 0.550 (a visible ~6% size mismatch between UI and terminal text, versus 0.7% for Adwaita Sans). Roboto is the other tabular-by-default option (all digits 1151/2048) but reads as the Android system font.

```nix
{config, ...}: {
  # Adwaita Sans / Inter digits are proportional by default (one=833 vs
  # four=1323 out of 2048 upem, measured with ttx), so the bar clock changes
  # width as the time changes and drags every widget to its right with it.
  # Both carry `tnum` in GSUB; fontconfig 2.17.1 supports the `fontfeatures`
  # property and Pango honours it. Noctalia sets no font features of its own
  # (no tnum/setFeature anywhere in its src tree), so this is the only lever.
  xdg.configFile."fontconfig/conf.d/52-ui-tabular-figures.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="font">
        <test name="family" compare="eq">
          <string>${config.stylix.fonts.sansSerif.name}</string>
        </test>
        <edit name="fontfeatures" mode="append">
          <string>tnum</string>
        </edit>
      </match>
    </fontconfig>
  '';
}
```

### 12. (medium) Delete the kitty module and stop installing kitty on every host

**File:** `modules/home-manager/terminal/kitty/default.nix`

**Rationale:** The module is not inert despite `programs.kitty.enable = false`. Its `home.file.".config/kitty/themes" = { source = ./themes; recursive = true; }` and `home.packages = [jetbrains-mono]` are top-level, outside the programs.kitty block, so every desktop rebuild ships a vendored Catppuccin diff-mocha.conf into ~/.config/kitty/themes and installs a second unpatched JetBrains Mono. The directory is imported wholesale by desktop-dev.nix via `builtins.attrValues outputs.homeManagerModules.terminal`, so there is no opting out short of deletion. Meanwhile kitty is genuinely installed — `modules/nixos/core/packages.nix` line 17 puts it in environment.systemPackages for *every* host including deadServer and deadPi, and /run/current-system/sw/bin/kitty resolves to kitty-0.48.2. That is why Noctalia's kitty template has been quietly maintaining a hand-written ~/.config/kitty/kitty.conf with a `current-theme.conf -> themes/noctalia.conf` symlink next to it. Since ghostty is the terminal, all of it goes. `vars.terminal = "kitty"` in flake/modules/constants.nix is also dead — grep finds no consumer anywhere in the repo.

**Verified against:** modules/home-manager/terminal/kitty/default.nix (home.file and home.packages are outside the programs.kitty attrset); modules/nixos/core/packages.nix:17; `readlink -f /run/current-system/sw/bin/kitty` = kitty-0.48.2; live `ls ~/.config/kitty` showing a real kitty.conf plus current-theme.conf -> themes/noctalia.conf; profiles/home-manager/desktop-dev.nix; grep for vars.terminal across modules/ hosts/ profiles/ flake/ (no hits); assets/templates/builtin.toml [templates.kitty] undo_hook

**Risk:** Removing kitty from core/packages.nix removes it from deadServer, deadPi and deadWsl too; if any of them is relied on for `kitty +kitten ssh` or the terminfo, that breaks. Disabling the Noctalia kitty template triggers its undo_hook, which removes ~/.config/kitty/themes/noctalia.conf and the include line it added — but the surrounding ~/.config/kitty/kitty.conf and kitty.conf.bak are hand-made files Nix never owned and will be left behind for manual cleanup.

```nix
# git rm -r modules/home-manager/terminal/kitty/
#   (default.nix + themes/diff-mocha.conf; auto-discovered by
#    flake/lib/registry.nix and imported by desktop-dev.nix via
#    `builtins.attrValues outputs.homeManagerModules.terminal`, so deleting
#    the directory is the whole change on the HM side)

# modules/nixos/core/packages.nix -- drop the system-wide kitty:
  environment.systemPackages = with pkgs; [
    curl
    git
    btop
    wl-clipboard
    superfile
  ];

# flake/modules/constants.nix -- `terminal = "kitty";` has no consumer
# anywhere in the repo (grep). Either delete it or set it to "ghostty".

# `kitty` is already dropped from theme.templates.builtin_ids in noctalia.nix.
```

### 13. (medium) Wire the new desktop domain into the HM profile and drop the stray host-level gtk.enable

**File:** `profiles/home-manager/desktop-dev.nix`

**Rationale:** There is no `desktop` domain under modules/home-manager/ today, but modules/nixos/ already has one, so `modules/home-manager/desktop/` is the placement that matches the existing shape and CLAUDE.md's registry rules — a directory with no default.nix recurses into a nested registry, so gtk.nix, qt.nix and fonts.nix become outputs.homeManagerModules.desktop.{gtk,qt,fonts} automatically. Importing the whole domain with attrValues matches how core/terminal/coding are already pulled in and means a future appearance module is live on the next rebuild once git-added. The alternative — dropping these into modules/home-manager/core/ — would work (profiles/home-manager/wsl.nix cherry-picks from core and would not pick them up) but core is the wrong semantic home for desktop-only GTK/Qt config. Removing `gtk = { enable = true; };` from hosts/deadPc/home.nix is required, not optional: with gtk.nix defining it, a second definition of the same option is a conflict, and leaving it host-local is exactly why deadConvertible currently has no GTK settings.ini at all despite Stylix's home.pointerCursor setting gtk.cursorTheme on it.

**Verified against:** flake/lib/registry.nix (directory without default.nix recurses; file name minus .nix becomes the attr); CLAUDE.md module/profile/host layering section; profiles/home-manager/desktop-dev.nix and desktop-gaming.nix; hosts/deadPc/home.nix `gtk = { enable = true; }` vs hosts/deadConvertible/home.nix (absent); modules/nixos/desktop/ as the existing precedent for a desktop domain

**Risk:** desktop-gaming.nix imports desktopDev, so both desktop hosts pick this up — which is the intent (the brief asks for changes that apply to both), but it does mean deadConvertible gains a 247 MB icon theme and the Papirus override rebuild on its next switch. The new module files must be `git add`ed before the first rebuild: untracked files are invisible to flake evaluation, so an unstaged desktop/ directory silently yields an empty registry and `builtins.attrValues` of nothing.

```nix
{outputs, ...}: {
  imports =
    [
      outputs.homeManagerModules.windowManager.hyprland
      outputs.homeManagerModules.browser.librewolf
    ]
    ++ (builtins.attrValues outputs.homeManagerModules.core)
    ++ (builtins.attrValues outputs.homeManagerModules.desktop)
    ++ (builtins.attrValues outputs.homeManagerModules.terminal)
    ++ (builtins.attrValues outputs.homeManagerModules.coding);
}

# hosts/deadPc/home.nix -- delete, now owned by desktop/gtk.nix:
#   gtk = {
#     enable = true;
#   };
```

## Open questions

1) TABULAR FIGURES UNDER QT is the one materially unresolved item. I confirmed fontconfig 2.17.1 supports `fontfeatures` and that Pango honours it, but not that Qt 6's fontconfig database applies it — and Noctalia is Qt. If the bar clock still shifts after the fontconfig rule lands, the fix is to change `stylix.fonts.sansSerif` to `pkgs.ibm-plex` / "IBM Plex Sans" (digits uniformly 600/1000, no feature needed) and accept a 0.516 vs 0.550 x-height mismatch with JetBrains Mono instead of 0.546 vs 0.550. Worth a single empirical check before committing to Adwaita Sans.

2) QT COVERAGE. I recommend `QT_QPA_PLATFORMTHEME=qt6ct`, which leaves pure-Qt5 apps (VLC 3.x) unthemed since there is no per-generation env var. The stronger end state is `plasma-integration` (Qt5 + Qt6) with `QT_QPA_PLATFORMTHEME=kde`, so both generations read the `~/.config/kdeglobals` that Noctalia's `kcolorscheme` template already writes and live-updates over D-Bus — one file, one source of truth, live reload. I did not verify its closure size or that it behaves outside a Plasma session. Worth deciding before writing desktop/qt.nix, because it changes that file entirely.

3) GHOSTTY WINDOW CHROME. `window-decoration = "client"` + `gtk-titlebar-style = "tabs"` is reasoned from the docs, not observed. If the merged tab/title bar looks wrong under Hyprland, `window-decoration = "none"` removes it entirely — but ghostty documents gtk-titlebar settings as having no effect in that mode and I could not confirm whether tabs survive.

4) ORDERING MATTERS ON THE FIRST SWITCH. `stylix.targets.gtk.enable = false` must land in the same rebuild as (or before) adding `gtk3`/`gtk4` to Noctalia's `builtin_ids`, and `stylix.targets.ghostty.enable = false` together with `theme = "noctalia"`. Getting it backwards leaves a Noctalia-written plain file where Home Manager expects its own symlink, and standalone HM has no `backupFileExtension` here, so the next switch hard-errors. Two files also need removing by hand before the first switch: `~/.config/qt6ct/qt6ct.conf` and `~/.config/gtk-3.0/gtk.css` if Noctalia has already replaced it.

5) NOT MY DOMAIN BUT ADJACENT: `xfconf`'s GSettings backend is currently the only one registered on this system (no `libdconfsettings.so`, no `gsettings` binary), so every GSettings write goes somewhere GTK does not read back. `programs.dconf.enable = true` is in my proposal, but whether `programs.xfconf.enable = true` in modules/nixos/desktop/packages.nix is still needed at all is a separate question — nothing in the repo obviously depends on it now that Thunar is gone (SUPER+E binds thunar, which is not installed).
