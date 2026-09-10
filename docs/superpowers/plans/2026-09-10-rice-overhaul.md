# Rice upgrade: Hyprland + Noctalia, wallpaper-driven

## Context

The desktop is built on strong components — Hyprland 0.56.2 (Lua config), Noctalia 5.0.1 (a native
Qt/QML Wayland shell: bar, launcher, notifications, lock, OSD, clipboard, session menu, wallpaper
daemon, idle manager), Stylix, ghostty — on a Ryzen 9 3900X / RTX 3070 with three 1080p monitors.
Almost none of it is tuned. Exploration and a 14-agent verified design pass found:

- **Every decoration and animation value is Hyprland stock** except `rounding = 5`. The bezier set
  deleted in `1f29958` turns out to have been a verbatim copy of the shipped default preset, so
  nothing was actually lost — but it also means there has never been an authored motion design.
  0.56.2 supports **spring-physics curves**, which the stock preset already uses for two leaves.
- **Zero windowrules, layerrules and workspacerules in the whole repo.** The Noctalia bar and every
  panel therefore get *no compositor blur at all*. This is the main reason the desktop reads flat.
- **The palette is static while the wallpaper rotates every 5 minutes.** Stylix pins Catppuccin
  Mocha at build time; Noctalia shuffles 27 varied wallpapers at runtime.
- **Two theming engines fight.** Stylix auto-enables `hyprpaper`, which is running now and painting
  a background layer *underneath* Noctalia's wallpaper layer on all three monitors.
- **Noctalia templates exactly one app — kitty — which is disabled.** Ghostty, the real terminal,
  is untemplated.
- **Three pieces of dead Noctalia v4 syntax.** Two produce validator warnings; the third — the
  inline `{id = "control-center"; useDistroLogo = true;}` bar entry — is discarded with *no
  diagnostic at all*, so the control-center button is simply missing from the bar.
- **`SUPER+L` and `SUPER+J` each fire two dispatchers today** (case-insensitive keysym collision).
  This is a live bug, not a cosmetic one.
- No icon theme anywhere. Qt writes no colour scheme. `sans-serif` resolves to Montserrat, a display
  face doing UI work. `SUPER+E` launches an uninstalled `thunar`. The avatar path dangles. No volume,
  media or brightness keys, so Noctalia's OSD has nothing to show. The machine never locks or blanks.

**Intended outcome:** a desktop that reads as one deliberately designed system in motion — colours
regenerated from the current wallpaper and pushed into every app that can accept them, chrome with
real depth and blur, authored animation, and none of the dead config underneath.

## Decisions taken

| Decision | Choice | Consequence |
|---|---|---|
| Colour authority | **Noctalia** (`theme.source = "wallpaper"`, `wallpaper_scheme = "vibrant"`) | Stylix demoted to fonts + cursor + apps Noctalia cannot reach. See the outcome note below: `m3-content` was the original pick and was wrong. |
| Chrome shape | **Full-width bar, capsule widgets** | `margin_ends` stays `0`; widgets in pills, translucent, blurred by a Hyprland layerrule. |
| Appetite | **Go all in**, one carve-out | New fonts, icon theme, packages in scope. |
| Login manager | **Keep tuigreet** | Greeter swap declined. `noctalia-greeter` 1.3.1 was verified viable but is **not** being adopted. Not in this plan. |
| Wallpaper rotation | **1800s** (from 300s) | A full recolour becomes an event, not a flicker. |
| Priority | **Animations** | Deepest treatment; spring physics. |
| Excluded | Desktop widgets, dock, hot corners, rounded screen corners | Declined. Not proposed. |

`m3-content` was chosen after measuring all 27 wallpapers (mean HSL saturation, lightness, and a
4-colour quantisation): 16 of 27 collapse to the same dark blue-grey ramp. The desaturating
generators (`muted`, `soft`, `faithful`) yield a colourless desktop on that set; `m3-fruit-salad`
and `m3-rainbow` spread three unrelated hues across the capsules. `m3-content` is the one option
giving both a full Material tonal ramp *and* enough chroma retention for the grey images.
`vibrant` is the runner-up and a one-word swap if it still reads too grey.

---

## Step 0 — branch

This changes a large share of the desktop, so it gets its own branch, which becomes the working
branch from here on.

```sh
git switch -c feat/rice-overhaul          # off current HEAD (feat/podman-migration @ 142be80)

git add docs/superpowers/plans/2026-08-18-nix-secrets.md \
        docs/superpowers/specs/2026-08-18-nix-secrets-design.md
git commit -m "docs(secrets): add sops-nix design and implementation plan"
```

Base is **current HEAD, not `main`**. `feat/podman-migration` is 21 commits ahead of `main` and
carries kernel 7.2 for deadPc, the nix-mineral hardening and the helium bump — all of which the
running desktop depends on. Branching from `main` would produce rebuilds that do not match the
actual machine. Everything on that branch comes along; it then goes dormant.

Both `nix-secrets` docs were scanned before committing: every apparent credential is a placeholder
(`your-deadmade-password`, elided `$y$…` hashes, `/run/nix-secrets/...` paths). No key material, no
base64 blobs, no real hashes — safe for a public repository.

Per `CLAUDE.md`, **untracked files are invisible to flake evaluation** — every new module file
(`modules/home-manager/desktop/gtk.nix`, `qt.nix`, `flake/lib/theme.nix`, …) must be `git add`ed
before it will build. Commits must be Conventional Commits; work inside `nix develop`.

---

## The single constraint that shapes everything

**Noctalia's builtin templates apply themselves by `cat > `-ing the target app's own config file.
Under Home Manager those files are read-only `/nix/store` symlinks, and every `apply.sh` runs under
`set -euo pipefail` — so the write fails with EACCES and the whole post-hook aborts silently.**

This is not a footnote; it decides which apps can be templated and how. Each template needs one of
three treatments:

| App | Treatment |
|---|---|
| `hyprland` | Config must contain the **literal** `require("noctalia")` — `apply.sh` guards with `grep -qF`, so the write becomes a no-op. Write it as `pcall(function() return require("noctalia") end)`; `pcall(require, "noctalia")` does **not** contain the literal and will fail. |
| `ghostty` | Keep `stylix.targets.ghostty` **enabled**; set `theme = lib.mkForce "noctalia";`. Its `apply.sh` greps for that line and no-ops. |
| `btop` | Keep the Stylix target; set `programs.btop.settings.color_theme = lib.mkForce "noctalia";`. Same no-op branch. |
| `gtk3` / `gtk4` | Must disable `stylix.targets.gtk` **and switch** *before* enabling the templates, so the file is no longer HM-owned. Order is mandatory. |
| `starship` | Not drop-in. Use a `[theme.templates.user.starship]` entry plus `programs.starship.configPath`. |
| `qt` | Template writes only the palette; qt6ct/qt5ct must be pointed at it (see Phase 2). |
| `bat`, `fzf`, `fastfetch`, `obs` | Write files **nothing reads**. Skip in pass one. `bat` in particular *breaks* — see landmines. |

---

## Landmines — read before touching anything

These were all confirmed by the adversarial pass. 34 of 104 proposals were refuted; these are the
ones that would have broken a build or a session.

1. **Every snippet is a fragment.** `noctalia.nix` already defines `shell`, `bar` and
   `control_center`; `config.nix` already defines `general` and `terminal._var`;
   `hosts/deadPc/config.nix` already defines `environment.systemPackages` and
   `users.users.deadmade.extraGroups`. Nix merges attr-path *prefixes* but errors on a duplicated
   *leaf* — `error: attribute 'x' already defined`. Everything below must be **merged into the
   existing blocks**, never pasted beside them.
2. **`rm ~/.config/qt6ct/qt6ct.conf` before the first switch.** It exists as a real 207-byte file;
   `xdg.configFile` will abort activation with "would be clobbered". Same class:
   `~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` must be plain-file-free before the gtk
   templates first run.
3. **Do not add `"bat"` to `community_ids`.** HM only runs `bat cache --build` at activation, so
   between the switch and the first Noctalia render every `bat` call fails with
   `unknown theme 'noctalia'` — and bat is this shell's pager.
4. **Do not reference `config.stylix.*` in `modules/home-manager/terminal/ghostty.nix`.**
   `profiles/home-manager/wsl.nix` imports the whole `terminal` domain, and `deadWsl` has no stylix
   module. Verified: `nix eval … deadWsl.config.stylix…` → `attribute 'stylix' missing`. It would
   break `nix flake check` and the WSL host.
5. **Keep `workspaces` in the bar.** With hyprsplit's 10-workspaces-per-monitor, dropping it leaves
   no workspace indicator on any of the three bars.
6. **Noctalia's `~/.local/state/noctalia/settings.toml` overrides the flake** and already holds a
   duplicate `[theme]` block. It will silently defeat `theme.source = "wallpaper"`. It must be
   cleared as part of Phase 2, and treated as a standing reproducibility hazard.
7. **`noctalia config validate` exits 0 on unknown keys and unknown enum values**, and does not
   check lane contents at all. A clean validate proves nothing about widget names or group ids.
8. **Do not move `librewolf` into `hooks.started`.** Hook commands are ordinary children of
   `noctalia.service`, so `KillMode=control-group` kills the browser on every `nhs` that touches
   Noctalia settings, and `Restart=on-failure` opens a second one. Keep the existing
   `hl.on("hyprland.start", …)`.
9. **Host-level `settings.animation` / `window_rule` additions need `lib.mkAfter`.** Two definitions
   concatenate with the *host's* entries first, so a host override would be emitted before the
   module's and lose. `deadConvertible/home.nix` must also gain `lib` in its argument set.
10. **Lists merge silently.** `behavior_order`, `osd.monitors` etc. defined in both a module and a
    host concatenate into nonsense with no error. Define each exactly once, or use `lib.mkForce`.
11. **`rm -rf ~/.config/hypr/noctalia/`** (a v4 orphan directory) before enabling the hyprland
    template, so `require("noctalia")` unambiguously resolves to `noctalia.lua`.

---

## Phase 1 — Foundation and hygiene

No visual change. Removes the conflicts that would otherwise corrupt every later phase.

**`modules/home-manager/core/stylix.nix`**
- `stylix.targets.hyprland.hyprpaper.enable = false;` — kills the duplicate wallpaper daemon that is
  painting under Noctalia on all three monitors.
- Delete `hyprlock.enable = false;` (valid but inert — hyprlock was removed in `1f29958`).

**`modules/home-manager/windowManager/hyprland/default.nix`**
- Delete the dead `inherit (import ../hosts/${host}/variables.nix) ;` binding (lines 8–11).
  `variables.nix` exists nowhere, and the relative path is wrong too; it survives only because the
  inherit list is empty.
- Fix the stale `# 0.55.x` comment — the pinned unstable resolves to 0.56.2.
- `services.network-manager-applet.enable = false;` and drop `networkmanagerapplet` — it is the only
  genuine tray duplicate. **blueman and solaar are not duplicates**; exploration was wrong about those.

**`modules/home-manager/windowManager/hyprland/noctalia.nix`**
- Delete the inline `{id = "control-center"; useDistroLogo = true;}` lane entry; replace with the id
  string `"control-center"` plus a `[widget.control-center]` block (`custom_image` /
  `custom_image_colorize` are the real v5 keys; `useDistroLogo` does not exist).
- `launcher_placement = "floating";` (the enum is `attached | floating`). Note this is *cosmetic* —
  the live effective value is already `floating`; it silences a warning and makes the flake honest.
- Delete the `calendar.cards` block; merge `calendar = { show_events_card; show_week_numbers; }`
  **inside** the existing `control_center` attrset.
- `avatar_path = "${../../assets/avatar.jpg}";` — fixes the dangling `~/.face`.
- `shell.launch_apps_as_systemd_services = true;` — today every `nhs` kills apps launched from the
  launcher.
- `shell.polkit_agent = true;` — GUI privilege prompts silently fail today.

**`hosts/deadConvertible/home.nix`** — delete the dead `services.wpaperd.settings` block (`enable`
is never set).

**`hosts/deadConvertible/config.nix`** — the hand-rolled portals and pipewire are drift, not a
deliberate divergence; import `nixosModules.desktop.base` instead.

**`flake/modules/constants.nix`** — `vars.terminal = "kitty"` and `vars.browser = "helium"` are
stale. Either delete the unused keys or make the Hyprland config consume them; check every consumer
first.

**Manual, outside Nix** (these mislead future debugging):
```sh
rm -rf ~/.config/hypr/noctalia/                    # v4 orphan — prerequisite for Phase 2
rm  ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.backup
rm  ~/.config/qt6ct/qt6ct.conf                     # else Phase 2 activation aborts
rm -rf ~/.config/noctalia/plugins/{ip-monitor,news,privacy-indicator}   # v4 QML, inert on v5
```

---

## Phase 2 — Colour authority, GTK, Qt and typography

The keystone. One coherent Stylix→Noctalia migration; GTK/Qt/fonts move in the same phase because
they touch the same Stylix targets.

**Noctalia theme block** (`noctalia.nix`)
```nix
theme = {
  source = "wallpaper";
  wallpaper_scheme = "m3-content";
  mode = "dark";          # not "auto" — that rewrites every templated file twice a day
  templates = {
    enable_builtin_templates = true;
    builtin_ids = ["hyprland" "gtk3" "gtk4" "qt"];
  };
};
```
Delete `customPalettes.stylix` and `custom_palette = "stylix"`. Leave `shell_mode` and
`pure_black_dark` unset — the defaults are correct, and pure black is wrong on three IPS panels.

**Wallpaper** — `interval_seconds = 1800`, `transition_on_startup = true`, trimmed transition set.

**Stylix demotion** (`modules/home-manager/core/stylix.nix`) — disable `gtk`, `qt`, and the hyprland
colour half. **Keep enabled:** `ghostty`, `btop`, `bat`, `fzf` (their files stay HM-owned and are
handled by the `mkForce` no-op trick or left Catppuccin). Disabling `fzf` would leave fzf with *no*
theme — its Noctalia template writes a file nothing sources.

**GTK** — new `modules/home-manager/desktop/gtk.nix`. Must carry the theme across, not just the font:
```nix
gtk = {
  enable = true;
  theme = { package = pkgs.adw-gtk3; name = "adw-gtk3-dark"; };   # apply.sh greps for this exact name
  iconTheme = { package = pkgs.papirus-icon-theme; name = "Papirus-Dark"; };
};
```
Do **not** use `papirus-icon-theme.override { color = …; }` without first checking
`papirus-folders -l` — an unknown colour is a build-time hard failure, and it forces a from-source
rebuild of a 247 MB theme. Note disabling `stylix.targets.gtk` also drops its Flatpak support
(`~/.themes` + a `GTK_THEME` override); re-declare
`services.flatpak.overrides.global.Environment.GTK_THEME` if you want it back.

**Qt** — use Home Manager's own `qt.qt5ctSettings` / `qt6ctSettings` options. They **do** exist
(verified: `nix eval … options.qt` lists them); do not hand-write INI. Point
`Appearance.color_scheme_path` at `${config.xdg.configHome}/qt6ct/colors/noctalia.conf`, which is
what Noctalia's `qt` template writes. Set `platformTheme = { name = "qt6ct"; package = pkgs.qt6Packages.qt6ct; };`
and drop any `environment.variables.QT_QPA_PLATFORMTHEME` so there is exactly one writer.

**Typography** (`stylix.nix`, both copies)
- `sansSerif` → **Adwaita Sans**; fix `serif` (currently also Montserrat); declare an emoji font.
- Add a `fonts.sizes` block — there is none today.
- `cursor.size` 25 → **24** (Bibata does not ship a 25px size).
- `git rm modules/nixos/core/themes.nix` — and do **not** add `fonts.packages = config.stylix.fonts.packages`.
  Stylix's `font-packages` target already does exactly that and is already on; adding it would list
  every font twice. Deletion alone fixes the duplicate JetBrains Mono. Note deadServer/deadPi lose
  system-wide nerd-fonts as a side effect.

**Shared Stylix base** — extract the hand-synced duplicate into `flake/lib/theme.nix` imported by
both `modules/nixos/desktop/stylix.nix` and `modules/home-manager/core/stylix.nix`.

**Clear the state override** before switching:
```sh
systemctl --user stop noctalia
# remove the [theme] block (and the stale lockscreen_widgets entries) from:
$EDITOR ~/.local/state/noctalia/settings.toml
```

**Order within this phase is mandatory:** disable `stylix.targets.gtk` and switch **first**, then
enable the `gtk3`/`gtk4` templates in a second switch.

---

## Phase 3 — The capsule bar

`modules/home-manager/windowManager/hyprland/noctalia.nix`, all merged into the existing single
`bar` block.

- `capsule = true` with `capsule_group` (an array-of-tables using `group:<id>` lane tokens),
  `capsule_fill = "surface_variant"`, `capsule_padding`, `capsule_thickness`.
- Lanes — **keep `workspaces` first and outside the pills**:
  `start = ["workspaces" "group:launch" "group:sys"]`.
- `background_opacity = 0.40` and `shell.panel.transparency_mode = "glass"`. **This is the
  precondition for Phase 4** — the bar is fully opaque today, so every blur change is invisible
  until this lands.
- Leave `backdrop` off — it is niri-only and does nothing under Hyprland.
- New widgets worth adding: `media`, `audio_visualizer`, `privacy`, `caffeine`, `screenshot`,
  `clipboard`. **Drop `battery` and `power_profile` on deadPc** unless Phase 5 installs upower and
  power-profiles-daemon — they have no data source and log errors today.
- `notification` and `osd`: pin `monitors = ["DP-3"]` so they appear once, on the centre panel,
  rather than on all three.
- German locale date/time formats.
- The `gpu` sysmon widget needs `LD_LIBRARY_PATH` for NVML via
  `systemd.user.services.noctalia.Service.Environment` — a sibling of `programs.noctalia`, not
  inside it.

---

## Phase 4 — Motion

`modules/home-manager/windowManager/hyprland/config.nix`. The Home Manager Lua renderer supports
`settings.curve`, `settings.animation`, `settings.window_rule` and `settings.layer_rule` directly.

**Curves** — a Material-3 emphasis pair, an overshoot, and two springs:
```nix
curve = [
  { name = "emphasis";   type = "bezier"; points = [[0.2 0.0] [0.0 1.0]]; }
  { name = "overshot";   type = "bezier"; points = [[0.05 0.9] [0.1 1.1]]; }
  { name = "snappy";     type = "spring"; mass = 1.0; stiffness = 300.0; dampening = 26.0; }
];
```
**Animations** — roughly 260 ms in / 160 ms out, spring motion on `windows`/`windowsIn`, and a
**looping `borderangle`** to drive the animated gradient border. On deadConvertible override it to
`style = "once"` using `lib.mkAfter` (see landmine 9).

**Blur** — `size = 6`, `passes = 3`, and **`popups = true`** (false today, which is why menus look
flat). Passes are exponentially more expensive than size; 3 passes at 5760×1080 is comfortable on a
3070.

**Shadows** — `range = 22`, downward `offset = [0 6]`, `scale = 0.97`, **neutral black, not
wallpaper-tinted** (a tinted shadow reads as a glow).

**Rounding** — `12` to match the bar exactly, plus `rounding_power = 2.4` for squircle corners.

**Opacity** — leave global opacity alone. `dim_inactive` does **not** earn its place on a
three-monitor setup; `dim_special` / `dim_around` do.

**Gradient borders** — multi-stop + angle, with colours coming from Noctalia's `hyprland` template.
Requires the literal `require("noctalia")` handshake (see the constraint table).

**Layer rules** — the repo's first. Blur + `ignore_alpha` on every Noctalia namespace, plus per-edge
`animation` so panels slide from the correct side. Get namespaces from `hyprctl layers`
(`noctalia-bar-default`, and the launcher/notification/OSD/control-center/session/lock surfaces).
`ignore_alpha = 0.25` is the load-bearing number and its inequality direction is **unproven** — if
the bar comes out unblurred, bisect `0.25 → 0.0 → remove the key` before touching
`background_opacity`.

**Window rules** — dialogs, per-app opacity, `idle_inhibit` for fullscreen video and games,
tearing on DP-3. Copy the `match` shape verbatim from the shipped
`share/hypr/hyprland.lua` — the key is **`pin`, not `pinned`**.

**`ghostty.nix`** — remove `background-blur`; it is a no-op under Hyprland.

**First render only:** `~/.config/hypr/noctalia.lua` does not exist yet, so the file watcher cannot
have registered it. Budget one explicit `hyprctl reload` after the first palette render.

---

## Phase 5 — Interaction

**Fix the live collision first.** `SUPER+L` and `SUPER+J` each currently fire *two* dispatchers
(case-insensitive keysym collision) — Hyprland runs every match.

**Rewrite the whole keybinding section**, do not append: the new binds for `SUPER+SPACE`, `X`, `N`,
`SHIFT+S`, `E`, `W`, `F` collide with existing lines that must be **deleted**.

- Media/volume/mic/brightness through `noctalia msg` so the OSD fires. Volume needs
  `{ repeating = true; locked = true; }`; media keys need `{ locked = true; }`.
- `panel-toggle notifications` is **dead** — there is no such panel. Notifications are a
  control-center *tab*.
- Mouse binds: `SUPER`+drag to move/resize (impossible today). Flag is `{ mouse = true; }`.
- `SUPER+E` → `ghostty -e yazi` (thunar is not installed); Nautilus on `SHIFT+E`. Edit the existing
  `fileManager._var` line in place.
- Resize submap on `SUPER+R`; scratchpad on `SUPER+minus`.
- `SUPER+V` is already float-toggle — move it before using it for the clipboard panel. Free keys:
  `B D G R T Z comma`.
- Idle ladder: deadPc 15 min lock / 20 min screens off / no suspend; deadConvertible 5 / 6 / 15.
- Drop `hyprshot` and `wofi-emoji` for Noctalia's built-ins — but **also remove the packages and
  rebind the keys**, or the processes keep running and the binds keep bypassing Noctalia.
  Add `hyprpicker` (currently only reachable inside the hyprshot wrapper).
- `services.upower.enable` + `services.power-profiles-daemon.enable` on deadPc — or drop the
  corresponding bar widgets. Note `programs.noctalia.recommendedServices.enable` in the input's
  **NixOS** module does exactly this, but importing it alongside the HM module would create a
  duplicate systemd user service; enable the two services directly instead.

---

## Verification

Per phase, in order. Do not proceed on a failed check.

```sh
nix develop                       # pre-commit hooks: alejandra, convco, trufflehog
nix flake check                   # custom outputs emit informational warnings — expected
nix eval .#homeConfigurations."deadmade@deadWsl".config.home.activationPackage  # guards landmine 4
```

**deadPc runs nix-mineral** — per `CLAUDE.md` use `nixos-rebuild boot` + reboot, not `switch`, so
the prior generation stays bootable.

- **Phase 1:** `hyprctl layers | grep -c hyprpaper` → `0`. `noctalia config validate` → the two
  known warnings gone. Control-center button visible on the bar.
- **Phase 2:** `noctalia config export full | grep -A3 '^\[theme\]'` shows `source = "wallpaper"`.
  Change the wallpaper from the control centre and confirm GTK apps, Qt apps and window borders all
  move together. In `qt6ct`, Appearance → Color scheme reads `noctalia`, and
  `env | grep QT_STYLE_OVERRIDE` is empty.
- **Phase 3:** bar visibly translucent; `workspaces` present on all three monitors; notifications
  appear only on DP-3.
- **Phase 4:** `hyprctl getoption decoration:blur:passes` → 3. Open a menu — it should blur. If the
  bar is not blurred, bisect `ignore_alpha` as above. Watch `journalctl --user -u noctalia` for
  template `apply.sh` EACCES errors, which are the signature failure of this whole design.
- **Phase 5:** `hyprctl binds | grep -c 'SUPER.*L'` → 1, not 2. Volume keys move the OSD. Lock fires
  after the idle timeout.

**Full verified design output** (104 proposals, 135 verdicts with file:line evidence and corrected
snippets) is at
`/tmp/claude-1000/-home-deadmade-nix-configuration/d8ca1b02-1a8d-481c-9020-c3c5c2c3156f/scratchpad/`
— `pair-*.json` and `corrections.md`. **Copy these into `docs/` as the first implementation step**;
the scratchpad is session-scoped and will be lost.


---

# Outcome (implemented 2026-09-10)

All five phases are implemented, switched and verified on deadPc. Commits `c8a5b5e`
(phase 1) through `e12ef5f` (phase 5).

## Corrections to this plan, made during implementation

**`m3-content` was the wrong scheme.** The plan reasoned about generator names; measuring
actual output contradicted it. Both Material generators push this dark, low-chroma wallpaper
set into a near-white pastel band, so the accent barely changed between wallpapers — which
defeats the point of wallpaper-driven colour:

| scheme | Clearnight.jpg | dark-waves.jpg |
|---|---|---|
| m3-content | `#bec2ff` | `#bec6e0` |
| m3-tonal-spot | `#bec2ff` | `#b0c6ff` |
| **vibrant** | **`#65a8e7`** | **`#6781e4`** |

`vibrant` also emits all 72 roles including the full `surface_container_*` ramp, so the plan's
stated reason for preferring a Material generator did not hold either.

**`hyprctl dispatch` is not a Lua eval channel.** It wraps its argument in
`return hl.dispatch(...)`, so the multi-statement hook the plan proposed is a syntax error.
`hyprctl eval` is the real channel and is what `hooks.colors_changed` uses.

**Gradient borders are a table, not a string.** The Lua setter rejects hyprlang's
`"col1 col2 45deg"` form with `invalid color`. `HL.Gradient` is
`string|{colors:string[], angle?:number}`.

**Idle behaviours need an explicit `action`.** Declaring an `[idle.behavior.<name>]` table
replaces the built-in entry rather than merging into it. `enabled` + `timeout` alone yields
`idle behavior 'lock' ignored: needs an action` at runtime, and `noctalia config validate`
does not catch it — only the journal does.

## Deferred, deliberately

- **ddcutil brightness on deadPc.** Needs `hardware.i2c.enable` plus i2c group membership,
  and whether the HP V27e / Acer XB252Q panels answer DDC/CI is unverified. `noctalia msg
  brightness-up` returns `brightness control unavailable` on this host; the binds are
  harmless no-ops there and work on deadConvertible's real backlight.
- **Noctalia Greeter.** Declined by the user. `noctalia-greeter` 1.3.1 is in nixpkgs and was
  verified viable (self-contained greetd session binary, polkit action for appearance sync),
  but it wants a dedicated system user and, below 1.5.0, cannot do passwordless sync.

## Pre-existing breakage found, not fixed

`hosts/deadConvertible/config.nix` pins `pkgs.unstable.ladybird`, which nixpkgs now marks
insecure, so that host cannot evaluate. It fails identically on `main` and predates this work.
deadConvertible's Home Manager config evaluates fine; only its NixOS side is blocked.

## Unmanaged files moved aside

`~/.config/rice-overhaul-backup-2026-09-10/` holds the v4 Noctalia colour orphan, the stale
`hyprland.conf` stub and its pre-Lua backup, the pre-existing `qt6ct.conf`, the three
hand-installed v4 QML plugins, and the Noctalia state file as it was before the `[theme]`
override was stripped. Delete when you are happy.
