# Rice upgrade: Hyprland + Noctalia, wallpaper-driven

> **Phases 1–5 are implemented and verified** (commits `c8a5b5e`…`f03a531`). See the Outcome
> section at the end. A second round — **Phase 6: the opening, and feel** — is being planned now;
> its brief is recorded directly below.

## Round 2 brief (2026-09-10)

The result of phases 1–5 was assessed as *"looks and feels really polished"* but lacking wow.
That is a fair diagnosis of a real mistake: every individual choice was optimised for restraint
(neutral shadows, `dim_inactive` off, a 45° gradient, accordion to avoid layout shift). Each was
defensible; the sum is tasteful and completely quiet.

**What "wow" means here, in the user's words:**

- *"something that when I open and use it just feels like noice, but it does not need to be like a
  show off here I can do that you cant"* — the payoff is in how it **feels to use**, not in effects
  that announce themselves. Not a demo reel. Rules out spectacle: no weather effects on the desktop,
  no gratuitous shaders, nothing whose purpose is to be pointed at.
- *"its okay to show the boot and the greeter. The Opening should start when I press enter on
  tuigreet"* — **Plymouth and the greeter restyle are both out of scope.** The "opening" is a much
  narrower and more interesting target: the moment between pressing enter in tuigreet and having a
  usable desktop. That transition is currently unchoreographed.
- Hyprland plugins and GLSL screen shaders: **attempt them, verify they build and behave on the
  NVIDIA proprietary driver, back out and report anything that does not.**

Also in scope, unrelated: fix the `starship.toml` defects left over from an abandoned
Gruvbox→Catppuccin migration.

**Taste calls taken:** static glow with the window border still rotating (one moving element, one
still — two rotating gradients is where ambient tips into gamer-RGB); a static screen shader, to be
tried; no lock-screen desktop capture; no screen-time tracking; plugins only where they make
something already built discoverable.

---

# Phase 6 — the opening, and feel

## What the exploration ruled out

Recording these so they are not re-proposed later:

- **There is no workspace overview on Hyprland 0.56.2, with or without plugins.** `hyprexpo`,
  `hyprtrails` and `hyprwinwrap` were *deleted upstream* on 2026-05-12 ("all: drop unmaintained
  plugins (#663)"). `hyprspace`, the surviving exposé, returns **404** from the binary cache against
  this exact `hyprland-0.56.2` store path and its upstream commits stop at "Fix Hyprland 0.55".
  `hyprsplit`'s C++ plugin is pinned at 0.54.3 and also 404s — which is exactly why this repo
  already vendors its Lua library instead.
- **`cursor:zoom_factor` has `min = 1`** — it is a magnifier and cannot zoom out. No overview there.
- **`misc:session_lock_xray` / `session_lock_blur`** would render the live desktop under the lock
  screen. That is the same privacy trade already declined for Noctalia's `blurred_desktop`. Excluded.
- **Animated screen shaders** are off the table: any shader referencing `time` or `pointer_*`
  requires `debug:damage_tracking = 0`, i.e. a permanent full 5760×1080 repaint on all three outputs.
- **`hyprfocus`** builds, but its flash-on-focus overlaps with glow's `color_inactive`. Glow wins.
- Noctalia's `[backdrop]` and `niri_overview_type_to_launch_enabled` are niri-gated in source.
  `pure_black_dark` is for OLED and would turn the 40%-alpha glass bar to grey mud on these IPS panels.

## 6a — The opening

> **The brief:** *"would it be possible to have like a animation on the start. Idk like ready player
> one when booting into the virtual world?"*

### The reveal already exists in Hyprland and has never been seen

`monitorAdded` is a real animation leaf, currently inheriting `global` and never configured.
Verified in `src/output/Monitor.cpp` at tag v0.56.2:

- `CMonitor::CMonitor()` (line 94) binds **two** animations to the `monitorAdded` config —
  `m_zoomAnimProgress` and `m_backgroundOpacity`.
- `CMonitor::onConnect()` (line 112) resets `m_zoomAnimProgress` to `0` and the frame counter to `0`.
  **`onConnect` runs for every monitor at compositor startup**, not just on hotplug.
- The present handler (line 164-173) waits **5 presentation frames** — deliberately, past modesetting
  — then fires `*m_zoomAnimProgress = 1.F`.
- `src/render/Renderer.cpp:2133-2136` maps it: `mouseZoomFactor = 2.0 - value`, with
  `mouseZoomUseMouse = false`.

So: **a 2× → 1× zoom-out of the entire monitor, plus a background fade, on every session start.**
That is precisely the "booting into the world" reveal, and it is native, free, and already firing.

**Why it has never been visible:** it inherits `global` (~1 s) and starts at first scanout — roughly
1.7–2.2 s *before* Noctalia paints the wallpaper at +3.2 s. It zooms out an empty screen and is over
before there is anything to zoom.

### Making it land

The fix is not to speed anything up, it is to **hold the zoom through the dead gap and release it as
the desktop arrives.** A dedicated bezier whose control points keep the value near 0 early and then
ease out — roughly `{0.85, 0.0}, {0.15, 1.0}` over ~4 s — leaves the monitor still at ~1.7–1.8× when
the wallpaper and bar first paint, then settles them into place over the following ~2 s.

The zoom is applied at monitor-render level, so it scales **everything** including the bar layer.
Combined with the wallpaper's own transition fading up from transparent at the same moment, and the
bar's `slide top` layer rule, the desktop assembles *while* zooming into place.

Two honest caveats:

- The timing depends on boot speed, which varies. The curve and duration will need one or two
  reboot-and-watch iterations to land; treat the numbers above as a starting point, not a result.
- `onConnect` also fires on monitor **hotplug**, so a ~4 s reveal replays when a display is plugged
  in. Rare here, and arguably desirable, but it is a real side effect.

### The rest of the opening

Measured from the journal: **3.23 s** of dead time from pressing enter to the first painted frame,
then a 1.5 s transition on top (~4.7 s to settled). Two findings reshape this:

- `transition_on_startup` fades up from **fully transparent** (`rgba(0,0,0,0.0F)`), *not* from black.
  So `misc:background_color` is both the 3.2 s holding colour **and** the colour the wallpaper
  emerges from. Noctalia's Hyprland template does not claim that key — it is unowned.
- **The startup transition type is chosen uniformly at random** from all six. The login reveal is
  currently a coin flip that can land on `honeycomb` or `stripes`, which are built to blend two
  *images* and read as artifacts against a solid colour.

Changes, in `config.nix` and `noctalia.nix`:

1. **Own `misc:background_color`** — set it inside the existing `_G.noctalia_apply()` wrapper from
   `noctalia.colors.surface`, so the holding colour tracks the wallpaper palette rather than sitting
   at Hyprland's stock `#111111` (which does not match the desktop's `rgb(1b1c22)` surface).
2. **`wallpaper.transition = ["fade"]`** — the only transition that is correct against a solid
   colour, and the least showy of the six for the 30-minute rotation as well. It is also the right
   partner for the monitor zoom above: the wallpaper fades *up* while the monitor zooms *out*, which
   layers cleanly. Noctalia's own `zoom` transition would compound into a double zoom.

   *Fallback if the native reveal cannot be made to land:* a fullscreen opaque "curtain" window
   spawned at session start via `hl.exec_cmd(cmd, rules)` and closed by `hl.timer` once the bar's
   `layer.opened` fires, with `windowsOut` styled as the reveal. More moving parts and an extra
   dependency — only if 6a's tuning fails.
3. **`shell.setup_wizard_enabled = false`** — currently only suppressed by a marker file in
   non-declarative `~/.local/state`.
4. **Stage librewolf.** It currently launches from `hyprland.start` and reaches the screen ~1.2 s
   *before* the bar and wallpaper exist, so the first thing seen after login is a browser on a bare
   field. Bind it to the **`layer.opened` event** matching namespace `noctalia-bar-default`, then
   `:remove()` the subscription — the desktop lands first, then the browser. (`hl.timer(fn, {timeout,
   type="oneshot"})` is the fallback. Noctalia's `hooks.started` is **not** usable: hook commands are
   children of `noctalia.service`, so `KillMode=control-group` would kill the browser on every `nhs`.)

## 6b — Depth and focus

`config.nix`, all verified against `ConfigValues.cpp` at tag v0.56.2:

- **`decoration:glow`** — the headline. An *inner* rim light (not an outer halo) that traces the
  existing `rounding_power = 2.4` squircle. `enabled`, `range = 8`, `render_power = 4` (fast falloff
  so it hugs the edge instead of washing window content), `color` as a static two-stop gradient built
  from `noctalia.colors` in the same wrapper as the border, and **`color_inactive` at low alpha**.
  That last is the real prize: a per-window focus cue that `dim_inactive` could not provide without
  permanently dimming two of three monitors. `glowangle` stays **disabled** per the taste call.
  `fadeGlow` gets an explicit curve so focus changes bloom rather than snap.
  Note there is no per-window `no_glow` rule — glow is global.
- **`decoration:motion_blur`** — `enabled`, `samples` (default 7, max 64). Windows smear along their
  travel vector while animating, which is what makes the under-damped `snappy` spring read as weight.
  ⚠️ The shader branches on `USE_ROUNDING && !USE_MOTION_BLUR`, strongly implying corners are not
  rounded during a blurred frame. **Verify visually before committing**; drop it if corners pop.
- **`decoration:blur:xray = true`** — floating windows blur the wallpaper rather than the tiled
  windows behind them. Cleaner glass for the dialog/portal float rules added in Phase 4.
- **`inactive_opacity = 0.98`** — a different mechanism from dim: lets blur show *through* unfocused
  windows instead of darkening them. Pairs with the glow's inactive colour.
- **`general:gaps_workspaces`** — a gutter between workspaces so the `slidefade 15%` transition reads
  as two surfaces passing rather than one continuous strip.
- **`group:groupbar:gradients`** plus matching `gradient_rounding` / `gradient_rounding_power` and
  palette colours. `SUPER+G` was bound in Phase 5 and the resulting groupbar is entirely unstyled.

## 6c — Screen shader

New file `modules/home-manager/windowManager/hyprland/shaders/grade.frag`, wired via
`decoration:screen_shader` (an **absolute** store path — the option resolves relative to the main
config, which is a store symlink). No plugin required; `hyprshade` is only a scheduler and is not used.

Static only — **no `time`, no `pointer_*` uniforms**. A gentle contrast/saturation lift plus a very
weak vignette, with both strengths as named constants at the top of the file so they are trivial to
tune or zero out. The vignette is deliberately weak: on a 5760 px triple-head, corner darkening
affects the outer edges of the side panels permanently.

⚠️ Landmine to record: Hyprland issue #14679 (closed *not planned*) — screen shaders silently no-op
on monitors set to 10-bit or wide colour management. These three are `XRGB8888` / `cm=srgb`, the
working configuration. Do not change monitor bitdepth without remembering this.

## 6d — Shell feel

`noctalia.nix`, all declarable and none blocked by the state file:

- `shell.launcher.app_grid = true` (icon grid for pure app searches; falls back to a list the moment
  a `/`-provider or calculator hit appears) and `shell.panel.list_item_background = true` (filled
  rounded row backgrounds — plays into the glass panels).
- `shell.animation.speed` — a global multiplier on every panel/OSD/notification transition. Tune
  slightly below 1.0 so panels feel weighted rather than snappy.
- `shell.session.grid = true` with `grid_columns = 3`, per-action `variant` (`destructive` on
  shutdown/reboot) and `countdown_seconds` on the destructive pair.
- `control_center.sidebar = "full"` and a wider `width`.
- `weather.enabled = true`. `location.address = "Augsburg"` is already set and `weather.effects` is
  already `true` — enabling weather unlocks an **animated, palette-tinted GLSL effect** (Rain / Snow /
  Cloud / Fog / Sun / Stars, chosen by WMO code) inside the Control Center's conditions card, and
  makes the lock screen's already-enabled weather row render something instead of nothing.

## 6e — Plugins

**Hyprland — `hypr-dynamic-cursors`** (narinfo **200** against this exact 0.56.2, so the ABI matches).
Cursor physics plus **shake-to-find** magnification, which is genuinely useful on a 5760 px desktop
where the pointer gets lost. Config namespace is `plugin:dynamic-cursors`.
Load it with **`hl.plugin.load("<abs .so>")` inside `extraConfig`**, *not* the Home Manager `plugins`
option: that option defers to `hl.on("hyprland.start", …)`, which fires after the whole Lua file is
evaluated, so the plugin's namespace would be `nil` at config-parse time.

**Noctalia — four plugins**, pinned reproducibly. They are sandboxed Luau scripts, so a
`[[plugins.source]]` with `kind = "path"` pointing at a `fetchFromGitHub` of the community repo
(rev `ea86850b8c21f9f8f3663021163b8f071040986d`) needs no build step. Also set
`plugins.auto_update = "none"` — it is currently `"all"`, i.e. a git pull on startup and every 6 hours.

Every one makes something built in phases 1–5 discoverable rather than adding decoration:

| Plugin | Makes discoverable |
|---|---|
| `kenn/keybind-cheatsheet` | The 93 rewritten binds. Ships `hyprland.lua` fixtures, so it parses the Lua config format. |
| `dunarand/tmux-provider` | `/tm` in the launcher; the terminal already autostarts tmux. |
| `k4n4t4/hypr-submap` | The resize submap added in Phase 5 — shows only while in one. |
| `jamesfeeder/special-workspaces` | The scratchpad added in Phase 5, which currently has no indicator. |

Noctalia 5.0.1 is at plugin API 25; these declare 3–9 and the field is a *minimum*. All declared
dependencies are present except `tmuxp`, which is optional (`use_tmuxp` defaults false).

## 6f — Starship

`modules/home-manager/terminal/starship/starship.toml`. Worse than first reported: **`purple` is a
*built-in* starship colour name**, so it does not fail — it silently resolves to raw ANSI magenta.
Proven by byte-dumping `starship explain`: the time segment emits `SGR 45` (8-colour) while every
other segment emits truecolor. So the clock is painted in a colour that ignores the palette entirely.

Fix all defects first, as they are wrong under any palette:

| Line(s) | Defect |
|---|---|
| 24, 26, 178, 188, 189 | `purple` → silently ANSI magenta. `[time]`'s own dead `style = "bg:peach"` reveals the intent. |
| 172 | `[docker_context]` uses Gruvbox `#83a598` and `color_bg3`; the latter resolves to nothing, tearing the powerline separators on both sides. |
| 47 | `orange = "#cba6f7"` is *mauve*'s hex, and `orange` is referenced nowhere. `mauve` is absent from the palette. |
| 187 | `fg:creen` — typo, resolves to nothing. |
| 31–41 | Dead `[palettes.gruvbox_dark]`. |
| 117, 121, 171, 177 | Four modules declare a `style` that can never render — an inner explicit style beats `$style`. |

Then hand the palette to Noctalia so the prompt tracks the wallpaper like everything else. **Do not
enable the builtin `starship` template id** — its `apply.sh` write-throughs `$STARSHIP_CONFIG`, which
is a store symlink → EACCES. Use a `[theme.templates.user.starship]` entry rendering to a writable
path instead. The seam is clean: Home Manager's starship module exports `STARSHIP_CONFIG`
*unconditionally* but only writes the file when `settings != {}` — so dropping `settings` and setting
`configPath` gives the env var without HM owning the file. No `mkForce`, no apply.sh in the loop.

Trade-off, consistent with the one already accepted for GTK and Qt: the prompt layout moves to a
`.tmpl` in this repo and the rendered output lives outside the store.

## Verification (Phase 6)

- `nix flake check`; all six host configs evaluate (deadConvertible's NixOS side remains blocked by
  the pre-existing insecure `ladybird` pin).
- `hyprctl configerrors` empty; `hyprctl getoption decoration:glow:enabled` → true;
  `hyprctl -j getoption decoration.screen_shader` → the store path, not `[[EMPTY]]`.
- `hyprctl plugin list` lists `dynamic-cursors`.
- `noctalia config validate` clean, **and** `journalctl --user -u noctalia` free of unmatched-token
  and "needs an action" style warnings — validate does not catch those.
- **The opening is verified by rebooting and reading the journal**: the bar/wallpaper layer surfaces
  must be created *before* librewolf's first window, inverting today's order.
- `starship explain` byte-dumped again: no `SGR 4x` 8-colour escapes should remain.

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
| Colour authority | **Noctalia** (`theme.source = "wallpaper"`, `wallpaper_scheme = "m3-content"`) | Stylix demoted to fonts + cursor + apps Noctalia cannot reach. |
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

# Phase 6 outcome (implemented 2026-09-10, commit `6c11985`)

## Backed out, having been tried

Both were authorised as "try them, back out if they fail".

- **`hypr-dynamic-cursors`** — builds, and `nix-store -q --references` confirms it links the *same*
  `hyprland-0.56.2` store path the compositor runs from. It still throws at init:
  `plugin crashed/threw in main: std::exception`. **A clean ABI match is not sufficient**; its
  `PLUGIN_INIT` calls something 0.56.2 no longer provides. Shake-to-find is therefore unavailable.
- **`k4n4t4/hypr-submap`** — loads, then every poll throws
  `submap.luau:39: invalid argument #1 to 'trim' (string expected, got table)`. It calls
  `noctalia.runAsync("hyprctl submap", cb)` expecting a string; this runtime hands the callback a
  table. It declares `plugin_api = 6` against a shell at 25 — but that field is a **minimum**, so it
  offers no protection against a changed callback signature.

Three plugins survive: `keybind-cheatsheet`, `tmux-provider`, `special-workspaces`.

## Deliberate deviations from the plan

- **The screen shader's vignette ships at `0.0`.** Not timidity — the shader runs *per monitor*, so
  `v_texcoord` is 0..1 on each output independently. Any vignette darkens the **inner** edges of the
  side panels, drawing a seam down both monitor boundaries instead of framing one 5760px desktop.
  The constant is present and documented for anyone going single-monitor.
- **Starship keeps its layout in this repo.** Rather than moving the prompt into a template, the
  template is *generated* by concatenating `starship.toml` with `noctalia-palette.tmpl`, so there is
  exactly one copy of the layout to maintain and only the palette is substituted.

## Still unverified — needs a reboot

The reveal (`monitorAdded` on the `reveal` curve at speed 40) is confirmed **registered**
(`hyprctl animations` shows `overridden: 1, bezier: reveal, enabled: 1, speed: 40.00`) but its
*visual timing* cannot be tested without a cold session start. Expect one or two rounds of tuning:

- If the desktop is already settled before the zoom is visible → **raise** `speed`.
- If the zoom is still obviously running after everything has landed → **lower** it.
- If it holds too long at full zoom → move the first control point down from `0.85`.

Both live in `modules/home-manager/windowManager/hyprland/config.nix` (`reveal` curve, `monitorAdded`
leaf).
