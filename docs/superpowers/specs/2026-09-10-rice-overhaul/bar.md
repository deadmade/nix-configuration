# Noctalia bar and chrome

_Noctalia bar + shell chrome (the capsule redesign)_

Noctalia v5 has a real, first-class capsule system: a bar-level `capsule = true` default plus `[[bar.<name>.capsule_group]]` array-of-tables referenced from a lane with a `group:<id>` token. I read bar.cpp's run-merging code and confirmed grouped members render exactly one shared pill while ungrouped widgets each get their own — so the design is "capsule everywhere, groups where things belong together". The bar becomes a nearly-transparent full-width glass rail (background_opacity 0.40) carrying opaque pills (capsule_opacity 0.90), with Hyprland — not Noctalia — owning the blur; Noctalia has no compositor blur of its own and `[backdrop]` is niri-only dead weight on Hyprland (verified in settings_window_scene.cpp: `niriBackdropSupported = compositors::isNiri()`). Every option name, enum and colour role below was run through `noctalia config validate` and came back with zero warnings; three of the current file's keys came back as warnings, which is exactly why they silently died. Widget selection is host-split: deadPc has no upower, no power-profiles-daemon and no /sys/class/power_supply at all, so battery/power_profile/brightness are gated behind a `host` argument that this repo declares but never actually passes.

## Fatal problems flagged by the verifier

Nothing here breaks the build. `programs.noctalia.checkConfig` defaults to true and runs `noctalia config validate` inside a runCommand, but I ran every proposed block through it and all exit 0 with zero warnings — and I proved warnings alone never fail the build (`noctalia config validate` on a file with `launcher_placement = "centered"` + `calendar.cards` exits 0). The Nix→TOML round trip through `pkgs.formats.toml.generate` produces correct `[[bar.default.capsule_group]]` array-of-tables and `[widget.control-center]` hyphenated keys, and validates clean.

Three things would break the SESSION or the intent, in priority order:

1. WORKSPACES IS GONE. No lane and no capsule_group member list contains "workspaces", while Change 6 configures nine `[widget.workspaces]` keys for it. On hyprsplit with 10 per-monitor workspaces you would rebuild into a desktop with no workspace indicator on any of the three bars. Fix: `start = [ "workspaces" "group:launch" "group:sys" ];`.

2. THE SNIPPETS ARE FRAGMENTS. Change 2 in particular is a syntactically complete module that puts `bar = {…}` at option level rather than under `programs.noctalia.settings`, and none of the snippets carry the existing `imports`, `customPalettes.stylix`, `theme`, `dock.enabled = false`, `wallpaper` or `home.file.".config/wallpapers"` blocks. A literal paste is an eval failure; a careless merge silently drops the Stylix palette wiring or re-enables the dock.

3. THE `host` LANDMINE IS LEFT ARMED. Change 1 makes `host` a real argument but leaves `inherit (import ../hosts/${host}/variables.nix) ;` in hyprland/default.nix. No `variables.nix` exists anywhere in the repo and the relative path resolves to `modules/home-manager/windowManager/hosts/<host>/` — wrong twice. It is inert today only because an `inherit` with zero names never forces its argument. Delete the `let … in` in the same commit.

One methodological warning the user should carry forward: `noctalia config validate` does NOT check lane widget names, capsule-group tokens, or action command strings. I proved this — `start = [ "group:nonexistent", "totally_fake_widget" ]` and `scroll_up = "not-a-real-command"` all pass silently. The design's headline claim that "every option name, enum and colour role was run through `noctalia config validate` and came back with zero warnings" therefore covers key names and enum values (where it is genuinely strong — an unknown widget key DOES warn) but not the one category the design's whole grouping architecture depends on. I re-verified all 24 widget names by hand against docs/user/bar/widgets/index.mdx and they are correct; the evidence just needs restating.

Also correct one factual overclaim in the summary: the live config produces TWO warnings, not three. The inline `{id = "control-center", useDistroLogo = true}` table at config.toml:14 draws no diagnostic at all — it is dropped in silence, which is worse and makes the argument stronger, not weaker.

## Verdicts

### [CONFIRMED] Change 1 — `host` is declared but never passed into extraSpecialArgs (the diagnosis)

**Evidence:** /home/deadmade/nix-configuration/flake/modules/home.nix:11 `mkHome = _hostName: hostConfig:` and lines 14-17 `extraSpecialArgs = { inherit inputs vars systems; outputs = projectOutputs; };` — no `host`. /home/deadmade/nix-configuration/modules/home-manager/windowManager/hyprland/default.nix:3 destructures `host`. `nix eval .#homeConfigurations."deadmade@deadPc".config.wayland.windowManager.hyprland.enable` → `true`, proving the missing arg is a lazy throw that is never forced. Home configs are built ONLY here (flake/modules/hosts.nix has no home-manager.nixosModules), so this is the only place that needs the edit.

**Correction:**

Snippet is correct but says "and update the call site" — unnecessary, the call site at home.nix:22 already passes `hostName`. The only edit is `_hostName` → `hostName` plus the one new line.

### [CONFIRMED] Change 1 — list-concatenation argument for computing lanes in a `let` instead of per-host overrides

**Evidence:** `nix eval --impure` on `lib.evalModules` with `options.settings = mkOption { type = (pkgs.formats.toml {}).type; }` and two modules defining `settings.bar.default.end = ["a" "b"]` / `["c"]` returned `[ "c" "a" "b" ]`. Merge path is types.either → listOf.merge → concat, via the recursive `oneOf` valueType in pkgs/pkgs-lib/formats.nix.

### [WRONG] Change 1 — design leaves a live landmine it should have removed in the same edit

**Evidence:** modules/home-manager/windowManager/hyprland/default.nix:8-10 contains `inherit (import ../hosts/${host}/variables.nix) ;`. `find /home/deadmade/nix-configuration -name variables.nix` returns NOTHING — no such file exists anywhere in the repo. The relative path is also wrong: from `modules/home-manager/windowManager/hyprland/`, `../hosts/` resolves to `modules/home-manager/windowManager/hosts/`. It survives only because `inherit (e);` with zero names never forces `e`.

**Correction:**

Delete the whole binding in the same change:

```nix
{
  lib,
  host,
  pkgs,
  inputs,
  ...
}:
with lib; {
  imports = [ ./config.nix ./noctalia.nix ];
  ...
}
```
Once `host` is a real argument, anyone who later adds a name to that `inherit` gets a path-not-found at eval time. Removing it is one line and closes the trap.

### [CONFIRMED] Change 2 — `capsule_group` array-of-tables, `group:<id>` tokens, and all bar geometry keys exist and survive Nix→TOML

**Evidence:** docs/user/bar/index.mdx:295-331 (`[[bar.<name>.capsule_group]]`, id/members/enabled/fill/border/foreground/padding/radius/opacity/accordion/accordion_direction/widget_spacing). src/shell/bar/bar.cpp:2545-2550 expands `group:` tokens via `capsuleSpecFromGroup`; src/config/config_types.cpp:479-499 sets `spec.enabled = true` unconditionally for groups (so bar-level `capsule` is irrelevant to them); bar.cpp:2751-2760 `canJoinCapsuleGroup` requires non-empty matching group + non-anchor. `noctalia config export full` confirms bar.default defaults incl. `capsule_group = []`, `capsule_padding = 6.0`, `capsule_thickness = 0.7599…`, `contact_shadow`, `panel_overlap`. I generated the design's bar block through `pkgs.formats.toml.generate` (nixpkgs bx7ivhrf…-source) → /nix/store/hm49nwyp143k33lci4irj96z7hkn1gw3-test.toml, which emits correct `[[bar.default.capsule_group]]` and `[widget.control-center]`, and `noctalia config validate` on it → "Config is valid", exit 0.

### [WRONG] Change 2 — the `workspaces` widget is dropped from the bar entirely

**Evidence:** Design's lanes: `start = ["group:launch" "group:sys"]`, `center = ["active_window"]`, `end = ["group:media" "group:status" "tray" "group:time" "notifications" "session"]`. No `workspaces` in any lane and no `group:` whose `members` contain it. The current config has it (`start = ["workspaces" …]`, live config.toml:18). Change 6 nevertheless spends a nine-key `[widget.workspaces]` block on `focused_output_only`, `labels_only_when_occupied`, `active_pill_size` etc. — all dead config for a widget that is never placed. On a hyprsplit 10-workspace-per-monitor setup this removes the only visual workspace indicator.

**Correction:**

```nix
      start  = [ "workspaces" "group:launch" "group:sys" ];
```
Or, if it should be part of a pill, put it in its own group so it doesn't merge with the launch capsule. Note `workspaces` reserves `left` (docs/user/bar/actions.mdx, "Widgets that own a gesture") so it can't be given a left binding.

### [WRONG] Change 2 — "every option name, enum and colour role was run through `noctalia config validate` and came back with zero warnings" is much weaker evidence than presented

**Evidence:** `noctalia config validate` does NOT check lane contents. I fed it `[bar.default] start = [ "group:nonexistent", "totally_fake_widget" ]` plus `dead_zone.actions.scroll_up = "not-a-real-command"` and it reported ZERO warnings for all three (it did flag `shell.panel.launcher_placement`, `calendar.cards`, `bar.default.launcher_placement`, `widget.foo.stat`). So a clean validate proves nothing about widget names, group ids, or action commands — exactly the class the design's grouping rests on. bar.cpp:2540 only `kLog.warn`s an unmatched group token at runtime.

**Correction:**

Every lane name in the design does in fact check out against docs/user/bar/widgets/index.mdx (control-center, launcher, clipboard, screenshot, cpu, gpu[defined], ram, network_rx, network_tx, media, audio_visualizer, privacy, caffeine, nightlight, bluetooth, network, volume, weather, date, clock, tray, notifications, session, active_window) — I verified them by hand. But the design should say "verified against the widget index", not "validate returned zero warnings".

### [WRONG] Change 2 — "three of the current file's keys came back as warnings"

**Evidence:** `noctalia config validate ~/.config/noctalia/config.toml` → exactly TWO warnings: `shell.panel.launcher_placement: unknown value "centered"` and `calendar.cards: unknown setting`. The inline table at config.toml:14 (`{id = "control-center", useDistroLogo = true}` inside `bar.default.end`) produces NO diagnostic at all; it is silently dropped, which `noctalia config export full` confirms (its `end` has no control-center entry).

**Correction:**

Restate as: two of the three warn; the third — the inline lane table — is discarded with no diagnostic whatsoever, which is the worse failure mode and reinforces the point.

### [CONFIRMED] Change 2/8/9 — a large fraction of the proposed keys are already the shipped defaults

**Evidence:** `noctalia config export full` shows these already at the proposed value: `margin_ends = 0`, `margin_edge = 0`, `concave_edge_corners = true`, `radius = 12`, `hover_highlight = true`, `show_on_workspace_switch = true`, `shadow = true`, `panel_overlap = 1`, `font_weight = 500`, `font_scale = 1.0`, `scale = 1.0`, `capsule_fill = "surface_variant"`, `position = "top"`, `shell.card_borders/input_borders/popup_borders/popup_shadows = true`, `shell.app_icon_colorize = false`, `shell.shared_gl_context = true`, `shell.disable_mipmaps = false`, `shell.time_format = "{:%H:%M}"`, `shell.animation.enabled = true`, `shell.panel.borders/shadow = true`, `control_center.show_shortcut_labels/show_session_button = true`, `control_center.calendar.show_events_card = true`, `weather.effects = true` (NOT an opt-in — it is on by default), `weather.refresh_minutes = 30`, `weather.unit = "metric"`, and Hyprland's `decoration:blur:new_optimizations` (hyprctl getoption → `bool: true set: false`). `network.vpn_status = "replace"` and `launcher.glyph = "search"` are likewise the documented defaults.

**Correction:**

Not errors — but the file's own comment says "only deviations from the defaults are set here". Trim these or the diff triples in size for no behaviour change. In particular do not sell `weather.effects = true` as "costs one boolean" — it is already on; only `weather.enabled = false → true` is the real change.

### [CONFIRMED] Change 3 — `useDistroLogo` is dead, `custom_image` / `custom_image_colorize` / `color` are the real mechanism, and the nixos-icons path is correct

**Evidence:** docs/user/bar/widgets/control-center.mdx lists exactly glyph / custom_image / custom_image_colorize; `useDistroLogo` appears nowhere in the v5 tree. docs/user/bar/widgets/index.mdx#widget-definitions confirms lane entries are bare strings resolving to `[widget.<name>]`. `nix build nixpkgs#nixos-icons` → /nix/store/isxvswqcwaxsddwdp9k0g6ywyazh3dp2-…; `find` confirms `share/icons/hicolor/scalable/apps/nix-snowflake-white.svg` AND `nix-snowflake.svg` both present. meson.build:79 `librsvg_dep = dependency('librsvg-2.0')`. `color` as a per-widget key: docs/user/bar/index.mdx:234. My generated TOML with `[widget.control-center]` + `[widget.control-center.actions]` validated clean.

**Correction:**

One nit: nixos-icons was not realised locally before I built it, so a first rebuild adds a substitution. Harmless.

### [CONFIRMED] Change 4 — `hl.layer_rule` is real Hyprland 0.56.2 Lua and every field name is right

**Evidence:** /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/hypr/stubs/hl.meta.lua:855 `---@field layer_rule fun(spec: HL.LayerRuleSpec): HL.LayerRule` and :555-569 `HL.LayerRuleSpec` with `blur?`, `blur_popups?`, `ignore_alpha? number|boolean`, `no_anim?`, `match? table<string,string|boolean>`, `name?`. Upstream snippet is verbatim from the noctalia tree at docs/user/compositor-settings/hyprland.mdx (Blur section). `hyprctl layers` confirms namespace `noctalia-bar-default` at `1920 0 1920 60` on all three outputs (a 60px surface for a 34px bar), and `noctalia-wallpaper` at 1920x1080 — correctly EXCLUDED by the regex. `hyprctl getoption decoration:blur:{size,passes,popups}` → 8 / 1 / false, so the proposed 6 / 3 / true are all real changes. The existing extraConfig contains no layer_rule, so no collision.

### [UNCERTAIN] Change 4 — the ignore_alpha inequality direction (the load-bearing number, 0.25)

**Evidence:** The Lua stub types it only as `ignore_alpha? number|boolean` (hl.meta.lua:562); the Hyprland package ships no wiki text and the binary is a wrapper script, so I could not locally prove that "alpha below the value is skipped" rather than "above". The noctalia doc pairs `ignore_alpha = 0.5` with a default `background_opacity = 1.0` bar, which is consistent with the design's reading but does not force it.

**Correction:**

Keep 0.25 (it is safe under either reading for a 0.40 rail) but treat it as the first thing to bisect if the bar comes out unblurred: try `ignore_alpha = 0.25`, then `0.0`, then removing the key, before touching `background_opacity`. Do not present it as proven.

### [CONFIRMED] Change 4 — `[backdrop]` is niri-only and should stay off

**Evidence:** src/shell/settings/settings_window_scene.cpp:746 `env.niriBackdropSupported = (m_wayland != nullptr && compositors::isNiri());`, settings_registry.cpp:2186/2195 gate the entries on it, and docs/user/desktop/wallpaper.mdx:114-132 describe it as a surface for niri's overview placed with `place-within-backdrop`. `noctalia config export full` shows `[backdrop] enabled = false`.

**Correction:**

Worth flagging explicitly to the user that this contradicts the letter of their decision #2 ("translucency, and a backdrop") — the design substitutes a Hyprland blur layerrule for it. That substitution is correct, but it is a decision the user has not seen stated as such.

### [CONFIRMED] Change 5 — panel keys, the `centered` refutation, and polkit

**Evidence:** `noctalia config export full` [shell.panel] contains every key used: transparency_mode, borders, shadow, list_item_background, floating_offset, {launcher,clipboard,polkit,control_center,session,wallpaper}_{placement,position}, open_near_click_*. docs/user/configuration/shell.mdx:234 "accept only `attached` or `floating` … `center` is a floating `*_position`, not a third placement"; :238 confirms open_near_click semantics and that it is IGNORED for a floating panel pinned to a non-`auto` position. `noctalia config validate` on a file with `launcher_placement = "centered"` → WARN, exit 0. meson.build:86-87 polkit_agent_dep/polkit_gobject_dep; `nix eval .#nixosConfigurations.deadPc.config.security.polkit.enable` → true and `systemctl is-active polkit` → active. `modules/home-manager/assets/avatar.jpg` exists (15k), and `../../assets/avatar.jpg` from noctalia.nix resolves there correctly. Whole block validates clean.

### [CONFIRMED] Change 6 — every `[widget.*]` key and enum is real, including gpu_usage / ram_pct / scroll_repeat / display

**Evidence:** src/shell/bar/widgets/sysmon_widget_definition.cpp:52 `.configValue = "gpu_usage"` and :72 `"ram_pct"`. docs/user/bar/widgets/sysmon.mdx (visualization gauge|graph|none, label_min_width, network_speed_compact), active-window.mdx (`display` = icon_and_text|icon_only|text_only), audio-visualizer.mdx (width/bands/mirrored/centered/show_when_idle/color_1/color_2), tray.mdx (hidden/pinned/hide_passive/drawer/drawer_columns/drawer_item_size), clock.mdx (format/tooltip_format), media.mdx (hide_when_no_media/art_size/title_scroll/max_length), network.mdx (show_label/vpn_status replace|both|hidden), notifications.mdx (hide_when_no_unread), weather.mdx, workspaces.mdx, bar/index.mdx:226 (per-widget font_weight) and :237 (scroll_repeat auto|gesture|steps). docs/user/theming/palette.mdx:16-32 confirms `primary`, `tertiary`, `outline`, `secondary`, `surface_variant` are all real roles. date-format-tokens.mdx:90 confirms the `-` modifier (`%-d`) is supported. `noctalia msg --help` confirms settings-open, volume-up/down, media <action>, panel-toggle. Control-center context ids incl. `calendar` and `notifications` at docs/user/control-center/index.mdx:64-65. I validated the entire widget block → "Config is valid", 0 warnings; a control test with `bogus_key_here` DID warn, so the pass is meaningful for key names.

### [UNCERTAIN] Change 6 — tray/hyprshot/wofi-emoji "retirement" hides symptoms without removing anything

**Evidence:** `tray.hidden = ["nm-applet" "blueman"]` only hides icons; modules/home-manager/windowManager/hyprland/default.nix:20-24 still installs `networkmanagerapplet`, `hyprshot`, `wofi-emoji` and sets `services.network-manager-applet.enable = true`. config.nix still binds SUPER+SHIFT+S to hyprshot and SUPER+X to wofi-emoji. So the processes keep running and the keybinds keep bypassing Noctalia.

**Correction:**

If the intent is retirement, pair the bar change with the package/bind removal:
```nix
    home.packages = with pkgs; [ ];            # drop hyprshot, wofi-emoji, networkmanagerapplet
    services.network-manager-applet.enable = false;
```
and in config.nix replace the two binds with `noctalia msg screenshot-region` and `noctalia msg panel-toggle launcher "/emo"`. Otherwise scope it honestly as "hide the duplicate icons".

### [CONFIRMED] Change 7 — notification/OSD keys, ranges, monitor pinning and exclusiveZone

**Evidence:** docs/user/services/notifications.mdx:42-44 (monitors = [] → all monitors; documented fallback when none connected), :55 (history_retention_hours 1–8760), :56 (max_visible 1–20). docs/user/configuration/shell.mdx:339-366 (osd position enum includes bottom_center; position vs position_vertical; full osd.kinds list). src/shell/notification/notification_toast.cpp:2070 `.exclusiveZone = 0`. hosts/deadConvertible/home.nix:21 confirms `eDP-1`; hosts/deadPc/home.nix confirms DP-3 is the 240Hz centre panel. Whole block validates clean.

### [CONFIRMED] Change 8 — control_center keys, `calendar.cards` refutation, six-shortcut cap, Power tab auto-hide

**Evidence:** `noctalia config validate` on the live file → `calendar.cards: unknown setting`. `noctalia config export full` [calendar] holds only enabled/event_date_format/event_time_format/refresh_minutes. docs/user/control-center/index.mdx:42-47 (sidebar full|compact|none, sidebar_section, width 600–1200, hidden_tabs), :59 (`monitor` = brightness tab), :184 "The tab itself is hidden on systems where neither UPower nor power-profiles-daemon is running". docs/user/control-center/shortcuts.mdx "Up to 6 shortcuts are shown" and the full type table (wifi/bluetooth/caffeine/nightlight/notification/wallpaper all legal). Live: `systemctl status upower` and `power-profiles-daemon` → "could not be found"; `ls /sys/class/power_supply/` → empty. Block validates clean.

### [CONFIRMED] Change 9 — shell polish keys all exist; numbers are unvalidated but in range

**Evidence:** `noctalia config export full` [shell] shows corner_radius_scale, button_borders, card_borders, input_borders, popup_borders, popup_shadows, app_icon_colorize, shared_gl_context, disable_mipmaps, password_style, date_format, time_format and [shell.animation] enabled/speed. docs/user/configuration/shell.mdx:27-47 documents corner_radius_scale 0–2 and password_style default|random. date-format-tokens.mdx:90 confirms `%-d`. Block validates clean. The design's own caveat that numeric ranges are unvalidated is correct — I confirmed `width = 5000`-class values pass.

### [CONFIRMED] Change 10 — NVML does not resolve by soname; the LD_LIBRARY_PATH fix and the HM merge both work

**Evidence:** src/system/system_monitor_service.cpp:873 `m_library = dlopen("libnvidia-ml.so.1", RTLD_LAZY | RTLD_LOCAL);`. `env -u LD_LIBRARY_PATH python3 -c "ctypes.CDLL('libnvidia-ml.so.1')"` → OSError cannot open shared object file; `LD_LIBRARY_PATH=/run/opengl-driver/lib python3 …` → LOADED. `/run/opengl-driver/lib/libnvidia-ml.so.1` symlinks into nvidia-x11-595.99.02. `/etc/ld.so.conf` does not exist at all. `tr '\0' '\n' < /proc/4475/environ | grep LD_LIBRARY` shows only NIX_LD_LIBRARY_PATH, and `grep -c nvidia-ml /proc/4475/maps` → 0. Merge target verified: nix/home-module.nix defines `systemd.user.services.noctalia.Service = { ExecStart; Restart; }`, and HM's modules/systemd.nix:177-186 declares `Service.Environment` as `coercedTo str lib.toList (listOf str)` — a real option, so a second definition merges.

**Correction:**

The design states the unit type as `attrsOf (attrsOf (either primitive (listOf primitive)))`; it is actually a submodule with a declared `Service.Environment` option at home-manager modules/systemd.nix:178. Conclusion unaffected. Also note `programs.noctalia.checkConfig` defaults true and runs `noctalia config validate` inside a `runCommand`, so a config-validate ERROR (not warning) fails the HM build — worth stating, since every block above exits 0.

### [WRONG] Cross-cutting — SUPER+V is already bound; the open question about binding clipboard would collide

**Evidence:** modules/home-manager/windowManager/hyprland/config.nix binds `hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))`. The design's open question 1 says "SUPER+V / SUPER+SPACE should be bound regardless" with no mention of the collision. SUPER+SPACE is already `noctalia msg panel-toggle launcher`, so that half is a no-op.

**Correction:**

Either move float-toggle (e.g. to SUPER+SHIFT+V) before taking SUPER+V for `noctalia msg panel-toggle clipboard`, or pick a free key. Free on deadPc today: SUPER+B, SUPER+D, SUPER+G, SUPER+R, SUPER+T, SUPER+Z, SUPER+comma.

### [CONFIRMED] Cross-cutting — open question 7 (`panel-toggle notifications` is broken) is right

**Evidence:** docs/user/ipc/surfaces.mdx:29-36 lists the complete panel id set: launcher, session, clipboard, wallpaper, control-center, plus `<author/plugin:entry>`. `notifications` is a control-center TAB context (docs/user/control-center/index.mdx:65), not a panel id. config.nix currently has `hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle notifications"))`.

**Correction:**

`hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"))`

### [UNCERTAIN] Cross-cutting — the snippets are fragments, not drop-in module text

**Evidence:** Change 2's snippet opens with a full module head `{ pkgs, config, inputs, vars, lib, host, ... }: let … in {` and then places `bar = { … }` at the top level of the returned attrset, with only a comment (`# ... inside programs.noctalia.settings:`) marking that it actually belongs under `programs.noctalia.settings`. Pasted literally it is a Home Manager module defining an option called `bar`, which fails evaluation. Changes 3/5/6/7/8/9 have the same shape at deeper indentation.

**Correction:**

Before this becomes a plan, restate Changes 2-9 as one contiguous rewrite of `modules/home-manager/windowManager/hyprland/noctalia.nix` showing the real nesting (`programs.noctalia.settings = { bar = …; widget = …; shell = …; notification = …; osd = …; control_center = …; }`) and the module-level `systemd.user.services.noctalia.Service.Environment` as a sibling of `programs.noctalia`. Also preserve the blocks the design never mentions but which exist today and must not be lost: `imports`, `home.file.".config/wallpapers"`, `customPalettes.stylix`, `theme`, `dock.enabled = false`, and `wallpaper.*`.

### [CONFIRMED] Cross-cutting — exclusions (f) and hardware (g)

**Evidence:** Nothing in the design enables `[desktop_widgets]`, `[dock]`, `[hot_corners]` or `shell.screen_corners` (all present in `noctalia config export full` and all left alone; the existing `dock.enabled = false` is preserved by omission). `margin_ends = 0` keeps the bar full-width, not floating. Hardware: RTX 3070 + 3x1080p makes blur size 6 / passes 3 over three 1920x60 strips trivial; battery/power_profile/brightness are correctly gated off deadPc (upower and power-profiles-daemon units "could not be found", /sys/class/power_supply empty, `[brightness] enable_ddcutil = false`); no fprintd dependency anywhere in the design.

## Proposed changes

### 1. (medium) Wire the `host` argument into Home Manager (it is declared today and would throw if touched)

**File:** `flake/modules/home.nix`

**Rationale:** modules/home-manager/windowManager/hyprland/default.nix already destructures `host` in its function head, but flake/modules/home.nix never puts it in extraSpecialArgs. It has not blown up only because nixpkgs' lib.modules turns a missing module argument into a *lazy throw*, and the sole use site is `inherit (import ../hosts/${host}/variables.nix) ;` — an inherit that binds zero names, so the expression is never forced. Confirmed: `nix eval .#homeConfigurations."deadmade@deadPc".config.wayland.windowManager.hyprland.enable` returns true today. One line makes the argument real and gives the bar an idiomatic host switch. The alternative — putting bar overrides in hosts/*/home.nix — is a trap: `pkgs.formats.toml`'s value type contains `listOf`, and I verified with lib.evalModules that two definitions of `settings.bar.default.end` CONCATENATE into `["c" "a" "b"]` rather than override. Every per-host lane change would need lib.mkForce. Computing the lists once inside a `let` avoids the whole class of bug.

**Verified against:** flake/modules/home.nix (mkHome/extraSpecialArgs); modules/home-manager/windowManager/hyprland/default.nix line 3; `nix eval --impure` on lib.evalModules with pkgs.formats.toml proving list concatenation; `nix eval .#homeConfigurations."deadmade@deadPc".config.home.username` → deadmade

**Risk:** Adding a specialArg cannot break existing modules (unused args are ignored). The only way this regresses is if some module has a *default* for `host` that this now shadows — grep shows none. Note the eval-cache SQLite "busy" warnings you get from concurrent nix eval are unrelated noise.

```nix
# flake/modules/home.nix — two edits

  # 1. name the binder (it is `_hostName` today):
  mkHome = hostName: hostConfig:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${hostConfig.system};
      extraSpecialArgs = {
        inherit inputs vars systems;
        # 2. hand the host name to every HM module. hyprland/default.nix already
        #    declares `host` in its arg set; without this it is a lazy throw.
        host = hostName;
        outputs = projectOutputs;
      };
      modules = [
        hostConfig.homeModule
      ];
    };

  # and update the call site:
  #   lib.nameValuePair "${vars.username}@${hostName}" (mkHome hostName hostConfig)
```

### 2. (high) Bar geometry + the capsule system + five capsule groups

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** NUMBERS, each one earned:
• thickness 36 (from 34): the pill height is `thickness * capsule_thickness`. At 0.75 that is 27px, which is the smallest pill that comfortably holds a ~18px line box plus 4-5px optical breathing room top and bottom. 34*0.75 = 25.5px reads cramped; 40 would eat 3.7% of a 1080p column for no gain.
• capsule_thickness 0.75 (default 0.76, rounded): leaves exactly 4.5px of rail above and below each pill, so the rail is visible as a rail rather than being fully covered by pills.
• padding 16 with radius 12: this pairing is NOT arbitrary. `concave_edge_corners = true` at `margin_edge = 0` carves the two BOTTOM corners of a top bar inward by `radius`. The carve is a shape on the bar background; widget capsules are laid out by the Flex and will visually overhang it if the first/last capsule starts inside the carve. padding must therefore exceed radius. 16 > 12 gives a 4px safety margin. (This answers the brief's question: yes, `radius` still does real work at margin_ends = 0 — it is the concave carve depth, capped at half the thickness, i.e. 18 here.)
• widget_spacing 8 at bar level vs 4-6 inside groups: a 2:1 ratio is the Gestalt-proximity minimum for "these are one object, those are separate objects" to read pre-attentively. 6:6 would make the groups invisible.
• capsule_padding 8.0 (default 6): at a 27px pill the end caps need more than 6px or the glyph looks shoved against the rounded edge.
• capsule_opacity 0.90 over background_opacity 0.40 → composite 0.94 vs 0.40, a 0.54 alpha delta. That is the figure/ground separation that makes the capsules the objects and the bar the rail. At capsule_opacity 0.6 the delta is 0.36 and the whole thing goes mushy.
GROUPING: bar.cpp's `canJoinCapsuleGroup` requires a non-empty `spec.group`, which is only set for declared group members — so ungrouped widgets can never accidentally merge, and `capsule = true` bar-wide is safe. Note `[[bar.<name>.capsule_group]]` is a real config surface even though the docs say "managed entirely from the Settings GUI".
SELECTION: dropped `battery` and `power_profile` from deadPc (no /sys/class/power_supply, no upower.service, no power-profiles-daemon — all three checked live). Added `gpu` (RTX 3070), `media` + `audio_visualizer` (your Discord/FreeTube/VLC/Telegram use), `privacy` (mic/cam/screenshare indicator, only draws when capturing), `clipboard` and `screenshot` (these retire wofi-emoji's overlap and hyprshot).

**Verified against:** docs/user/bar/index.mdx ("Widget Capsule" and "Capsule groups" tables); src/shell/bar/bar.cpp:2535-2553 (group token expansion) and :2751-2795 (canJoinCapsuleGroup / capsule run merging); `noctalia config export full` (bar.default defaults incl. capsule_group = [], capsule_padding = 6.0, capsule_thickness = 0.759…); `noctalia config validate` on the full block → "Config is valid", 0 warnings; `systemctl status upower` / `power-profiles-daemon` → not found; `ls /sys/class/power_supply/` → empty

**Risk:** Estimated width budget on a 1920px output: start ~390px (collapsed accordion + 5 sysmon), center ~340px, end ~780px = ~1510 of 1920. Comfortable, but `active_window.max_length` is the first thing to cut if a group turns out wider than modelled. `padding = 16` is the load-bearing number: if you later raise `radius` above 16 the end capsules will overhang the concave carve. Do not set `anchor = true` on any group member — bar.cpp's `canJoinCapsuleGroup` returns false for anchors and would split the pill in half.

```nix
# top of modules/home-manager/windowManager/hyprland/noctalia.nix
{ pkgs, config, inputs, vars, lib, host, ... }:
let
  isLaptop = host == "deadConvertible";

  # Widgets with no data source on a desktop: verified `systemctl status upower`
  # and `power-profiles-daemon` are both "could not be found" and
  # /sys/class/power_supply is empty on deadPc.
  statusMembers =
    [ "privacy" "caffeine" "nightlight" "bluetooth" "network" "volume" ]
    ++ lib.optionals isLaptop [ "brightness" "power_profile" "battery" ];
in
{
  # ... inside programs.noctalia.settings:

  bar = {
    # Keep the bar named "default": the Hyprland layerrule matches the live
    # namespace `noctalia-bar-default` (confirmed with `hyprctl layers`).
    order = [ "default" ];

    default = {
      position   = "top";
      thickness  = 36;       # -> 27px pills at capsule_thickness 0.75
      margin_ends = 0;       # full-width, edge to edge
      margin_edge = 0;       # required for concave_edge_corners
      padding    = 16;       # MUST exceed `radius` so the first/last capsule
                             # clears the concave corner carve
      widget_spacing = 8;    # between capsules/groups (2x the in-group gap)
      radius     = 12;       # depth of the two bottom-corner concave carves
      concave_edge_corners = true;
      background_opacity = 0.40;
      shadow          = true;
      contact_shadow  = true;   # dark gradient at the attached-panel seam
      panel_overlap   = 1;      # scale 1.0, no fractional scaling -> 1 is right
      hover_highlight = true;   # inside a group only the hovered member lights
      show_on_workspace_switch = true;
      font_weight = 500;
      font_scale  = 1.0;
      scale       = 1.0;

      # Capsule defaults for every widget on this bar. Widgets inside a
      # capsule_group inherit the GROUP's style instead (bar.cpp:2546).
      capsule           = true;
      capsule_fill      = "surface_variant";
      capsule_opacity   = 0.90;
      capsule_padding   = 8.0;
      capsule_thickness = 0.75;

      start  = [ "group:launch" "group:sys" ];
      center = [ "active_window" ];
      end    = [ "group:media" "group:status" "tray" "group:time"
                 "notifications" "session" ];

      capsule_group = [
        {
          id = "launch";
          members = [ "control-center" "launcher" "clipboard" "screenshot" ];
          accordion = true;            # collapse to the NixOS logo, unfold on hover
          accordion_direction = "end";
          widget_spacing = 4;
          padding = 8.0;
          opacity = 0.90;
        }
        {
          id = "sys";
          members = [ "cpu" "gpu" "ram" "network_rx" "network_tx" ];
          widget_spacing = 6;
          padding = 8.0;
          opacity = 0.90;
        }
        {
          id = "media";
          members = [ "media" "audio_visualizer" ];
          widget_spacing = 4;
          padding = 8.0;
          opacity = 0.90;
        }
        {
          id = "status";
          members = statusMembers;
          widget_spacing = 4;
          padding = 8.0;
          opacity = 0.90;
        }
        {
          id = "time";
          members = [ "weather" "date" "clock" ];
          widget_spacing = 6;
          padding = 8.0;
          opacity = 0.90;
        }
      ];

      # The dead zone is every part of the bar no widget covers. Scroll
      # anywhere on the rail to change volume.
      dead_zone.actions = {
        scroll_up   = "volume-up";
        scroll_down = "volume-down";
        back        = "media previous";
        forward     = "media next";
      };
    };
  };
}
```

### 3. (high) Fix the control-center widget and put a real NixOS logo on it

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `{ id = "control-center"; useDistroLogo = true; }` is v4 shape. In v5 a lane entry is a bare STRING; per-widget settings live in a separate top-level `[widget.<name>]` table (docs/user/bar/widgets/index.mdx: "When a name in a widget list matches a [widget.<name>] entry, that entry's type and settings are used"). `useDistroLogo` does not exist anywhere in v5 — the correct keys are `glyph`, `custom_image`, `custom_image_colorize` (docs/user/bar/widgets/control-center.mdx). I verified an inline table in a lane is silently dropped by re-reading the LIVE config: `noctalia config export full` shows `end = [ "tray", "battery", "volume", "network", "session", "clock", "notifications" ]` — the control-center entry is simply gone.
LOGO SOURCE: nixpkgs `nixos-icons` ships /share/icons/hicolor/scalable/apps/nix-snowflake.svg (official blue gradient) and nix-snowflake-white.svg (flat white). Noctalia rasterises SVG through librsvg (meson.build:79, src/render/core/image_file_loader.cpp:399 rsvg_handle_new_from_data), so an SVG works. Use the WHITE one with `custom_image_colorize = true` and `color = "primary"`: a flat white source tints cleanly to a single palette colour, whereas colorizing the two-tone blue one flattens a gradient and looks muddy — and leaving the official blue uncolorized will fight a wallpaper-derived Material You palette every 30 minutes. The `${pkgs.nixos-icons}` store path is embedded in config.toml, and Nix scans generated text files for store hashes, so the reference keeps the package from being garbage-collected without needing it in home.packages.

**Verified against:** docs/user/bar/widgets/control-center.mdx (glyph / custom_image / custom_image_colorize table); docs/user/bar/widgets/index.mdx (#widget-definitions); `noctalia config export full` showing the inline-table entry absent from bar.default.end; meson.build:79 librsvg_dep; src/render/core/image_file_loader.cpp:399 rasterizeSvg; `nix eval .#nixosConfigurations.deadPc.pkgs.nixos-icons.outPath` then `find` → nix-snowflake.svg and nix-snowflake-white.svg both present in share/icons/hicolor/scalable/apps/

**Risk:** Low. If the file path is ever wrong the widget falls back to its `glyph` ("noctalia") rather than failing — so a silent fallback is the failure mode, not a crash. Check the pill actually shows a snowflake after the first rebuild.

```nix
# in programs.noctalia.settings — a NEW top-level `widget` table

  widget = {
    # v5: lane entries are plain strings; per-widget settings live here.
    # `useDistroLogo` does not exist in v5 — this is the real mechanism.
    "control-center" = {
      custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg";
      custom_image_colorize = true;   # tint the flat-white snowflake with `color`
      color = "primary";              # follows the palette, incl. wallpaper mode
      actions = {
        right  = "settings-open";
        middle = "none";
      };
    };

    launcher = { glyph = "search"; };
  };

# If you would rather keep the official NixOS blue, use the other asset and
# turn colorize off — but expect it to clash once theme.source = "wallpaper":
#   custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
#   custom_image_colorize = false;
```

### 4. (high) Translucency: bar 0.40 + panels "glass", and the Hyprland ignore_alpha that must pair with it

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** WHO OWNS THE BLUR: Noctalia. Has. No. Blur. `transparency_mode` sets ALPHA only ("solid keeps cards opaque … glass makes both visibly translucent while clamping card opacity high enough for readable text" — shell.mdx:229). The blur must come from Hyprland, and Noctalia ships the exact layerrule in its own docs (compositor-settings/hyprland.mdx). So: HYPRLAND OWNS THE BLUR, NOCTALIA OWNS THE ALPHA. There is no double-blur risk — there is only one blur.
THE TRAP, and this is the number that matters: Hyprland's `ignorealpha` means "pixels with alpha BELOW this value are not blurred at all". Noctalia's docs pair `ignore_alpha = 0.5` with a default bar at background_opacity 1.0. If you drop the bar to 0.40 and leave ignore_alpha at 0.5, the rail is BELOW the threshold and Hyprland skips it entirely — you get a transparent unblurred band with blurred pills floating in it. So ignore_alpha must be 0.25: comfortably under the 0.40 rail, and still above the ~0 alpha of the empty region of the bar's layer surface (which `hyprctl layers` shows is 60px tall for a 36px bar, so a chunk of it IS fully transparent and must stay unblurred).
WHY 0.40 for the rail: with `capsule = true` bar-wide every piece of TEXT sits on a 0.90 pill, so the rail itself carries no legibility duty — it only has to read as an object. Below ~0.30 the band's lower edge stops separating from a bright wallpaper and the bar dissolves; 0.40 is the lowest value that still draws the rail. Blur passes 3 (up from the current 1) is what makes 0.40 survivable — one pass leaves recognisable wallpaper detail showing through.
BACKDROP: leave `[backdrop].enabled = false`. It is niri-only — settings_window_scene.cpp:746 sets `env.niriBackdropSupported = compositors::isNiri()` and settings_registry.cpp:2195 hides the entries when false; the docs describe it as a surface for "niri's overview" placed with `place-within-backdrop`, which Hyprland has no concept of. Enabling it on Hyprland pins a blurred full-res wallpaper copy in VRAM for every output for the shell's lifetime and renders nothing. The thing you actually want when you say "backdrop" is this layerrule.

**Verified against:** docs/user/compositor-settings/hyprland.mdx (the upstream layer_rule, verbatim namespaces); docs/user/configuration/shell.mdx:229 (transparency_mode is opacity, not blur); src/shell/settings/settings_window_scene.cpp:746 + settings_registry.cpp:2186-2195 (niriBackdropSupported); docs/user/desktop/wallpaper.mdx:112-134 (backdrop is for niri overview); `hyprctl layers` → namespace noctalia-bar-default, 1920x60 surfaces; `hyprctl getoption decoration:blur:{size,passes,popups}` → 8 / 1 / false

**Risk:** If the motion/animation domain ships its own layer_rule for the same namespaces, Hyprland applies the FIRST matching rule — coordinate so there is exactly one. size 6 / passes 3 on an RTX 3070 driving 5760x1080 is trivial, but the blur is recomputed per frame on the 240Hz DP-3, so if you ever see the bar cost frames, drop to passes 2 before touching opacity. If you decide to keep the rail at the documented 0.75 instead, put ignore_alpha back to 0.5 — the two numbers move together.

```nix
# modules/home-manager/windowManager/hyprland/config.nix — add to extraConfig.
# This is Noctalia's own recommended rule, with ignore_alpha retuned for a
# translucent bar and blur_popups enabled (blur:popups is false today).

      -- Noctalia surfaces: Hyprland owns the blur, Noctalia owns the alpha.
      -- ignore_alpha MUST stay below bar.default.background_opacity (0.40) or
      -- Hyprland skips the rail entirely and only the capsules get blurred.
      hl.layer_rule({
        name = "noctalia",
        match = {
          namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
        },
        no_anim = true,          -- let Noctalia's own animations run unopposed
        ignore_alpha = 0.25,
        blur = true,
        blur_popups = true,
      })

# and in the declarative `config.decoration` block (currently just `rounding = 5`):

        decoration = {
          rounding = 5;
          blur = {
            enabled = true;
            size = 6;      # smaller kernel, more passes = smoother at less cost
            passes = 3;    # 1 pass leaves wallpaper detail legible at 0.40 alpha
            popups = true; # needed for Noctalia dropdowns/menus
            new_optimizations = true;
          };
        };
```

### 5. (high) Panels: fix the invalid launcher_placement and design panel feel

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `launcher_placement = "centered"` is not a value. The enum is `attached | floating` only — "`center` is a floating `*_position`, not a third placement" (shell.mdx:234). Proof it is being discarded: `noctalia config export full` shows the effective `shell.panel.launcher_placement = "floating"`, i.e. the default, and `noctalia config validate` on it emits `unknown value "centered"` — a WARNING, so the HM build still succeeds. That is the whole reason this and the other two dead keys have survived.
`transparency_mode = "glass"` is the right pick over `soft`: glass makes floating panels AND their internal cards visibly translucent but self-clamps card opacity high enough for readable text, so it cannot produce an unreadable panel the way a hand-tuned alpha could. It only pays off because the layerrule blurs `noctalia-panel` and `noctalia-attached-panel`.
`list_item_background = true` is required with glass: launcher and clipboard rows have no fill by default (default false), and unfilled rows over a blurred wallpaper are exactly where glass UIs fall apart.
`open_near_click_*` is the fix for moving control-center to the far left: without it an ATTACHED panel opens at bar-CENTRE regardless of which button you pressed, so a left-anchored NixOS logo would fire a panel 900px away. Same argument for the far-right session button.
`floating_offset = 10` over the default 8 to sit on the same 8/16 rhythm as the bar's padding.
`polkit_agent = true` costs one boolean and fixes the "no polkit agent running" defect with zero new packages — noctalia links polkit-agent-1 and polkit-gobject-1 directly (meson.build:86-87), and `polkit_placement`/`polkit_position` already exist in the schema.

**Verified against:** docs/user/configuration/shell.mdx:75-96 and :229-238; `noctalia config export full` → shell.panel.launcher_placement = "floating" (the "centered" definition was discarded); `noctalia config validate` on a file containing launcher_placement = "centered" → WARN unknown value, exit 0; meson.build:86-87 polkit_agent_dep/polkit_gobject_dep; `git ls-files` → modules/home-manager/assets/avatar.jpg

**Risk:** `polkit_agent = true` will conflict if anything else claims org.freedesktop.PolicyKit1.AuthenticationAgent — nothing does today (the brief confirms no agent is running), but if you later add one, whichever registers second loses. `glass` is the most aggressive transparency_mode; if any panel text reads poorly over a bright wallpaper, `soft` is the one-word step down and needs no other change.

```nix
      shell = {
        avatar_path = "${../../assets/avatar.jpg}";  # ~/.face does not exist;
                                                     # the repo already tracks this
        polkit_agent = true;   # noctalia links polkit-agent-1; no extra package

        panel = {
          # "centered" was never a value. placement is attached|floating;
          # `center` is a *_position. This is the corrected pair.
          transparency_mode = "glass";
          borders = true;
          shadow  = true;
          list_item_background = true;   # glass needs a fill behind list rows
          floating_offset = 10;

          launcher_placement  = "floating";
          launcher_position   = "center";
          clipboard_placement = "floating";
          clipboard_position  = "center";
          polkit_placement    = "floating";
          polkit_position     = "center";

          control_center_placement = "attached";
          session_placement        = "attached";
          wallpaper_placement      = "attached";

          # Attached panels anchor at bar-CENTRE by default. The control-center
          # button now lives at the far left and session at the far right, so
          # both must follow the click instead.
          open_near_click_control_center = true;
          open_near_click_session        = true;
        };
      };
```

### 6. (high) Every `[widget.*]` definition — sysmon, media, visualizer, tray, workspaces, clock

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** NUMBERS:
• `label_min_width` on the two net widgets = 44px. A compact rate swings from "0" to "12.3M" as you scroll a page; without a floor the pill resizes continuously and drags every widget to its right along with it. 44px covers the widest compact string (~5 chars at ~13px) so the layout freezes.
• `visualization`: cpu/gpu/ram get "graph" (trend), net gets "none" (bare rate). Three gauges plus two rates would be five competing ring shapes in one pill; one visual language for the three utilisation stats and plain text for the two rates is legible at a glance.
• I dropped the `temp` widget you have today, because hovering ANY sysmon widget lists every other available sysmon stat in the tooltip (sysmon.mdx). CPU package temp on a 3900X is not an actionable at-a-glance number; it is a hover number. That buys the width for `gpu`.
• `audio_visualizer` needs NO cava — it reads the PipeWire monitor stream directly. bands 18 over the default 16 at width 56 gives ~3px bars, the narrowest that still reads as discrete bars rather than a blur. `show_when_idle = false` lets the group collapse when nothing plays.
• `tray.hidden = ["nm-applet" "blueman"]` retires the duplicate tray agents from the bar in one line, since the status group already carries `network` and `bluetooth`. Solaar stays — Logitech device battery is information nothing else provides.
• `date` is a SECOND clock instance (the built-in `[widget.date]` preset, type = "clock"). A two-line clock would need ~30px of text in a 27px pill; two pills side by side in `group:time` is the only way to show date and time at thickness 36.
• German formats: LC_TIME is de_DE.UTF-8 (modules/nixos/core/localization.nix:15), so `%x` renders `09/10/26` — I checked, it is NOT the German form. `%a %-d. %b` gives "Do 10. Sep" and `%A, %-d. %B %Y` gives "Donnerstag, 10. September 2026".
• `focused_output_only = true` on workspaces: with three bars showing three workspace strips, only the monitor you are actually on should show a focused pill; the other two show theirs as occupied.

**Verified against:** docs/user/bar/widgets/{sysmon,audio-visualizer,media,tray,workspaces,clock,network,volume,weather,notifications,active-window}.mdx; docs/user/services/system-monitor.mdx (#available-stats: gpu_usage/gpu_temp/gpu_vram, ram_pct, net_rx/net_tx); docs/user/bar/actions.mdx (gesture vocabulary, `left` reserved on workspaces/tray); `noctalia msg --help` (volume-up, media, panel-toggle control-center <tab>); `noctalia config export full` (built-in widget presets cpu/temp/ram/date/network_rx/network_tx/media/spacer); modules/nixos/core/localization.nix:15; `LC_TIME=de_DE.UTF-8 date +"%A, %x"` → "Thursday, 09/10/26"; `noctalia config validate` on the whole block → valid, 0 warnings

**Risk:** `gpu` depends on the NVML change below; without it the widget draws its glyph and reports the stat as unavailable rather than disappearing, so you would be paying pill width for nothing. `workspaces` uses hyprsplit's per-monitor workspace sets — `focused_output_only` and `labels_only_when_occupied` have not been seen together against hyprsplit, so glance at the strip after the first rebuild. `tray.hidden` matches by id/name/bus token; if nm-applet still shows, run `noctalia msg status` and use the exact bus name it reports.

```nix
  widget = {
    "control-center" = { /* see the logo change */ };

    # --- sysmon cluster (group:sys) ---
    cpu = { type = "sysmon"; stat = "cpu_usage"; visualization = "graph";
            show_value = true; label_min_width = 34; };
    gpu = { type = "sysmon"; stat = "gpu_usage"; visualization = "graph";
            show_value = true; label_min_width = 34; };
    ram = { type = "sysmon"; stat = "ram_pct";   visualization = "graph";
            show_value = true; label_min_width = 34; };
    network_rx = { type = "sysmon"; stat = "net_rx"; visualization = "none";
                   network_speed_compact = true; label_min_width = 44; };
    network_tx = { type = "sysmon"; stat = "net_tx"; visualization = "none";
                   network_speed_compact = true; label_min_width = 44; };

    # --- centre ---
    active_window = {
      display = "icon_and_text";
      icon_size = 16;
      min_length = 0;
      max_length = 340;
      title_scroll = "on_hover";
    };

    # --- group:media. No cava: the visualizer reads the PipeWire monitor. ---
    media = {
      max_length = 200;
      art_size = 18;
      title_scroll = "on_hover";
      hide_when_no_media = true;
    };
    audio_visualizer = {
      type = "audio_visualizer";
      width = 56;
      bands = 18;
      mirrored = true;
      centered = true;
      show_when_idle = false;
      color_1 = "primary";
      color_2 = "tertiary";
      actions.left = "media toggle";
    };

    # --- group:status ---
    network = { show_label = false; vpn_status = "replace"; };
    volume  = { show_label = false; };

    # --- tray: one drawer button, duplicates suppressed ---
    tray = {
      drawer = true;
      drawer_columns = 3;
      drawer_item_size = 20;
      hide_passive = true;
      hidden = [ "nm-applet" "blueman" ];   # noctalia already owns net + bt
    };

    # --- group:time. LC_TIME is de_DE.UTF-8, so %x gives 09/10/26, not the
    #     German form. Spell the German order out explicitly.
    weather = { show_condition = false; show_temperature = true; max_length = 90; };
    date    = { type = "clock"; format = "{:%a %-d. %b}";
                actions.left = "panel-toggle control-center calendar"; };
    clock   = { format = "{:%H:%M}"; font_weight = 600;
                tooltip_format = "{:%A, %-d. %B %Y}";
                actions.left = "panel-toggle control-center calendar"; };

    notifications = { hide_when_no_unread = false; };  # keep the DND right-click target

    workspaces = {
      style = "regular";
      show_labels = true;
      label_source = "id";
      labels_only_when_occupied = true;
      active_pill_size = 2.4;
      inactive_pill_size = 1.0;
      focused_color = "primary";
      occupied_color = "secondary";
      empty_color = "outline";
      focused_output_only = true;   # 3 bars: only the focused monitor highlights
      scroll_repeat = "steps";
    };
  };
```

### 7. (medium) Notifications and OSD: pin them to one monitor and get the offsets right

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** THE THREE-MONITOR ANSWER, verified: `monitors = []` shows the toast on ALL monitors, not the focused one (notifications.mdx:42, "monitors = [] shows notifications on all monitors (default)"). On 5760x1080 that means every Discord ping paints three times across the desk. Pin to the centre 240Hz panel — that is where you are looking — and the documented fallback covers the failure case: "If none of the configured monitors are currently connected … Noctalia falls back to showing toasts on all available monitors so notifications never disappear silently." This value is per-host (DP-3 vs eDP-1), which is the concrete payoff of the `host` argument.
OFFSET, and the docs are misleading here: notifications.mdx calls offset_y an "absolute margin from the screen edge", but src/shell/notification/notification_toast.cpp:2069 builds the layer surface with `.exclusiveZone = 0`, which in wlr-layer-shell means the compositor arranges the surface INSIDE the remaining space — i.e. already below the bar's reserved zone. So offset_y = 8 is an 8px gap under the bar, not 8px from the raw screen top. Do NOT add the bar thickness to it. offset_x = 16 aligns the toast's right edge with the last capsule (bar padding is 16).
max_visible 4: a toast is ~90px; `max_visible = 0` means "fill available space", which on 1080p is eleven stacked toasts during a Discord burst. 4 caps the stack at ~400px (37% of the column) and queues the rest, which is what the queueing logic is for.
history_retention_hours 168 = 7 days. `0` keeps history forever and the control-center list becomes an unusable archive; a week is the span over which "what was that notification" is still a real question. Range is 0-8760.
OSD to bottom_center: `top_center` puts the volume popup directly on top of the centre lane's active_window title, on the same layer as the bar. offset_y 48 from the raw bottom edge (no bottom exclusive zone) lifts it clear of maximised window chrome and roughly balances the 36px bar plus its shadow at the top.
`osd.kinds.media = false`: with a `media` widget in the bar the track title is already permanently visible, so a track-change popup on every song is pure duplication. brightness/power_profile/keyboard_backlight are switched off on deadPc because none of them have a data source.

**Verified against:** docs/user/services/notifications.mdx:42-44; docs/user/configuration/shell.mdx:336-381 (OSD position enum incl. bottom_center, osd.kinds); src/shell/notification/notification_toast.cpp:2064-2078 (LayerSurfaceConfig .exclusiveZone = 0, namespace noctalia-notification); src/wayland/layer_surface.h:41 (default exclusiveZone 0); `noctalia config export full` (notification/osd defaults: max_visible 0, history_retention_hours 0, monitors []); `noctalia config validate` → valid

**Risk:** Pinning to DP-3 means a notification fired while you are looking at the left monitor appears 1920px away. That is the deliberate trade against triplication; if it bites, `monitors = []` restores the old behaviour with no other change. `layer = "overlay"` puts toasts above fullscreen games — correct for Discord pings, wrong if you want a game to be uninterruptible, in which case use "top".

```nix
      notification = {
        position = "top_right";
        layer = "overlay";              # above fullscreen games
        monitors = [ (if isLaptop then "eDP-1" else "DP-3") ];
        background_opacity = 0.88;      # the layerrule blurs noctalia-notification
        border = true;
        offset_x = 16;                  # aligns with bar padding
        offset_y = 8;                   # exclusiveZone = 0 -> already below the bar
        max_visible = 4;                # 0 = fill the whole 1080px column
        history_retention_hours = 168;  # 7 days; 0 = forever
        collapse_on_dismiss = true;
      };

      osd = {
        enabled = true;
        position = "bottom_center";      # top_center collides with active_window
        orientation = "horizontal";
        monitors = [ (if isLaptop then "eDP-1" else "DP-3") ];
        background_opacity = 0.90;
        border = true;
        offset_y = 48;
        kinds = {
          media = false;               # the bar media widget already shows this
        } // lib.optionalAttrs (!isLaptop) {
          brightness = false;          # no backlight on deadPc
          power_profile = false;       # no power-profiles-daemon on deadPc
          keyboard_backlight = false;
        };
      };
```

### 8. (medium) Control Center, delete the dead calendar.cards block, turn weather on

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `calendar.cards` is the third piece of dead v4 syntax: `noctalia config validate` reports `calendar.cards: unknown setting`, and the live schema shows `[calendar]` holds only enabled / event_date_format / event_time_format / refresh_minutes. It has never suppressed anything. Delete it; the clock popup is now the control-center calendar tab, reached by the clock's left-click binding.
`sidebar = "full"` + `width = 760`: with weather enabled the sidebar carries Home/Media/Audio/System/Network/Bluetooth/Weather/Calendar/Notifications — nine icon-only tabs is a memory test. `width` is documented as the FULL-sidebar width, so 760 (range 600-1200) leaves ~580px of content column after a labelled sidebar, which is what the media artwork and system graphs need. `sidebar_section = "compact"` keeps it icon-only when you open straight to a tab by clicking the volume or network widget — the pair exists precisely for this.
`hidden_tabs = ["monitor"]` on deadPc: the Monitor (brightness) tab "remains available but has no write controls to expose" with no writable backlight. The Power tab hides itself automatically ("the tab itself is hidden on systems where neither UPower nor power-profiles-daemon is running"), so it does not need listing.
SHORTCUTS: only 6 are shown and your current list has 7, with `power_profile` dead on deadPc — so today one working shortcut is being pushed off the end by one that cannot function. The deadPc six are all live.
`show_week_numbers = true`: German calendars are read in Kalenderwochen, and the doc confirms it works with `[calendar].enabled = false` and no accounts configured — it is a decoration of the month grid.
WEATHER: you typed an address but left it off. `effects = true` turns out to be animated GLSL shaders selected from the Open-Meteo weather code — Rain, Snow, Cloud, Fog, Sun, Stars (weather_tab.cpp:1194-1211) — drawn behind the Weather tab header. It is the single most charming thing in the shell and it costs one boolean.

**Verified against:** `noctalia config validate` → "calendar.cards: unknown setting"; `noctalia config export full` [calendar] and [control_center] sections; docs/user/control-center/index.mdx (sidebar/width/hidden_tabs table, per-tab availability rules, Power tab hidden without UPower/PPD); docs/user/control-center/shortcuts.mdx (only 6 shown, full type list); docs/user/services/weather.mdx (effects = visual weather effects); src/shell/control_center/tabs/weather_tab.cpp:1005 and :1194-1211 (effectForWeatherCode → Rain/Snow/Cloud/Fog/Sun/Stars)

**Risk:** Enabling weather starts a 30-minute outbound request to Open-Meteo carrying your geocoded coordinates. `[shell].offline_mode = true` is the global kill switch if you want it off later. Also note the `weather` bar widget only renders when `[weather].enabled = true` — the bar's group:time depends on this change.

```nix
      control_center = {
        sidebar = "full";              # 9 tabs is too many to navigate icon-only
        sidebar_section = "compact";   # but stay compact when opened to a tab
        width = 760;                   # full-sidebar width, range 600-1200
        show_shortcut_labels = true;
        show_session_button = true;
        # Monitor = brightness, and deadPc has no writable backlight. Power
        # hides itself when neither UPower nor PPD is present.
        hidden_tabs = lib.optionals (!isLaptop) [ "monitor" ];

        calendar = {
          show_events_card = true;
          show_week_numbers = true;    # ISO KW — German convention
        };

        # Only 6 are ever rendered. The old list had 7 including power_profile,
        # which has no daemon on deadPc, so a live shortcut was being dropped.
        shortcuts =
          [ { type = "wifi"; } { type = "bluetooth"; } { type = "caffeine"; }
            { type = "nightlight"; } { type = "notification"; } ]
          ++ [ (if isLaptop then { type = "power_profile"; }
                            else { type = "wallpaper"; }) ];
      };

      # v5 [calendar] is ONLY account sync + shared formats. The old
      # `calendar.cards` list was an unknown setting and did nothing.
      calendar.enabled = false;

      weather = {
        enabled = true;                # you already set location.address
        unit = "metric";
        refresh_minutes = 30;
        effects = true;                # animated rain/snow/fog/stars shaders
      };

      location.address = "Augsburg";
```

### 9. (medium) Shell polish: animation speed, borders, password style, German date

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** NUMBERS:
• `animation.speed = 0.9` (0.5 = 2x slower, 2.0 = 2x faster). Slightly SLOWER, not faster: Noctalia's panel transitions land around 200ms at 1.0; 0.9 puts them near 222ms, inside the 200-250ms band where motion reads as deliberate craft, and still well under the ~300ms where UI starts to feel laggy. On a 240Hz panel that is 53 frames of motion to look at instead of 48. Given "animations are awesome", this is the correct direction.
• `corner_radius_scale = 1.15`: ties panel and card corners to the pill language of the bar without going full bubble. 2.0 is "extra rounded" and would fight the 12px concave carve.
• `button_borders = false` while card/input/popup borders stay true: in a Material You palette a button is already a filled tonal surface, so an outline on top of a fill is a second, redundant signal. Cards, inputs and popups have no fill of their own under `glass` and genuinely need the outline to hold their edges against a blurred wallpaper. This is a deliberate split, not a blanket setting.
• `password_style = "random"`: the lockscreen draws a random number of dots so a shoulder-surfer cannot count your password length. Zero cost, real benefit, and the only other legal value is "default".
• `date_format = "%A, %-d. %B"`: `%x` under de_DE.UTF-8 renders `09/10/26` (checked with `date`), which is neither American nor German. `%A, %-d. %B` gives "Donnerstag, 10. September".
• `app_icon_colorize` stays FALSE deliberately — tinting app icons to the palette destroys the brand recognition that makes a tray and a launcher scannable. Listing it explicitly so nobody flips it looking for more Material You.
• `shared_gl_context` stays TRUE deliberately — with three outputs it uploads each wallpaper texture once instead of three times; the journal shows `[texcache] hit … (refCount=3)` doing exactly that. Only flip it if you see vertical stripe artifacts.

**Verified against:** docs/user/configuration/shell.mdx:20-73 and :227-228 (animation, shadow, borders semantics); `noctalia config export full` [shell] block (all current values); `noctalia config validate` on the block → valid, 0 warnings; range-probe file with corner_radius_scale = 5.0 → accepted, proving numbers are unvalidated; `LC_TIME=de_DE.UTF-8 date +"%A, %x | %A, %-d. %B"` → "Thursday, 09/10/26 | Thursday, 10. September"; journalctl --user -u noctalia → [texcache] hit … refCount=3

**Risk:** `corner_radius_scale` is clamped at runtime, not validated (`noctalia config validate` accepted 5.0 without complaint), so an out-of-range value fails silently rather than loudly. 1.15 is inside the documented 0-2 range. `animation.speed = 0.9` is global and also slows the lockscreen and OSD; if anything feels draggy, 1.0 is the neutral point.

```nix
      shell = {
        corner_radius_scale = 1.15;   # 0 = square, 1 = default, 2 = extra round
        button_borders = false;       # filled tonal buttons need no outline too
        card_borders   = true;        # cards/inputs/popups have no fill under
        input_borders  = true;        # `glass` and DO need the edge
        popup_borders  = true;
        popup_shadows  = true;

        app_icon_colorize = false;    # deliberate: keep app brand colours
        shared_gl_context = true;     # deliberate: 3 outputs share wallpaper VRAM
        disable_mipmaps   = false;

        password_style = "random";    # hide password length on the lockscreen

        # LC_TIME is de_DE.UTF-8, where %x renders 09/10/26. Spell it out.
        date_format = "%A, %-d. %B";  # "Donnerstag, 10. September"
        time_format = "{:%H:%M}";

        animation = {
          enabled = true;
          speed = 0.9;   # ~222ms transitions: deliberate, not sluggish
        };

        # shadow.direction/alpha are global (bars, panels, OSD, lockscreen all
        # share them) and 0.55 is already well judged — alpha is multiplied by
        # each surface's own background opacity, so the 0.40 rail casts an
        # effective 0.22 shadow on its own. Left at the default on purpose.
      };
```

### 10. (medium) Make the `gpu` sysmon widget actually work: NVML needs LD_LIBRARY_PATH

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Noctalia reads NVIDIA stats by `dlopen("libnvidia-ml.so.1", RTLD_LAZY|RTLD_LOCAL)` — by SONAME, with no path (src/system/system_monitor_service.cpp:873). Its docs are explicit that it does not shell out to nvidia-smi. On NixOS the library lives at /run/opengl-driver/lib (confirmed: symlink to nvidia-x11-595.99.02) but that directory is not on the loader path: /etc/ld.so.conf is EMPTY, the systemd user manager environment has no LD_LIBRARY_PATH, and `env -u LD_LIBRARY_PATH python3 -c "ctypes.CDLL('libnvidia-ml.so.1')"` fails with "cannot open shared object file". So `gpu_usage`, `gpu_temp` and `gpu_vram` would report unavailable forever, and the control-center System tab would show no GPU section. The dlopen is lazy (`ensureReady` is only called on the first GPU read), which is why nothing has been logged — `grep libnvidia-ml /proc/<pid>/maps` returns nothing because nothing has ever asked for a GPU stat. The noctalia HM module builds `systemd.user.services.noctalia` itself, and the unit's freeform type is `attrsOf (attrsOf (either primitive (listOf primitive)))`, so a second definition of `Service` merges cleanly and adds Environment without touching ExecStart.

**Verified against:** src/system/system_monitor_service.cpp:864-905 (ensureReady/dlopen by soname, lazy State::Uninitialized); docs/user/services/system-monitor.mdx (#gpu-data-sources: "Noctalia loads NVML directly and does not run [nvidia-smi]"); `ls /run/opengl-driver/lib/libnvidia-ml.so.1` → symlink into nvidia-x11-595.99.02; `cat /etc/ld.so.conf` → empty; `systemctl --user show-environment | grep LD_LIBRARY` → nothing; `env -u LD_LIBRARY_PATH python3 -c "ctypes.CDLL('libnvidia-ml.so.1')"` → OSError cannot open shared object file; home-manager modules/systemd.nix:95-110 (unit freeform type attrsOf (attrsOf (either primitive (listOf primitive))))

**Risk:** LD_LIBRARY_PATH applies to the whole process, so /run/opengl-driver/lib gets first refusal on every library noctalia loads. That directory holds only graphics driver libraries — which is exactly what a Wayland shell should be resolving from anyway — but it is a blunt instrument and is the standard NixOS workaround rather than an elegant one. Harmless on deadConvertible even if that host has no NVIDIA: a nonexistent or irrelevant entry in LD_LIBRARY_PATH costs one failed stat() at startup. If the grep above still comes back empty after a rebuild, drop "gpu" from the sys capsule group rather than chasing it.

```nix
  # modules/home-manager/windowManager/hyprland/noctalia.nix, at module level
  # (a sibling of `programs.noctalia`, not inside it):

  # Noctalia dlopens libnvidia-ml.so.1 by SONAME for GPU stats
  # (src/system/system_monitor_service.cpp:873). On NixOS the driver libs live
  # in /run/opengl-driver/lib, which is on no loader path for a systemd user
  # unit — /etc/ld.so.conf is empty. Without this, stat = "gpu_usage" is
  # permanently "unavailable" and the control-center System tab shows no GPU.
  systemd.user.services.noctalia.Service.Environment = [
    "LD_LIBRARY_PATH=/run/opengl-driver/lib"
  ];

  # Verify after the rebuild:
  #   grep libnvidia-ml /proc/$(pgrep -f bin/noctalia)/maps
  # (open the control-center System tab first — the dlopen is lazy.)
```

## Open questions

1) ACCORDION on the launch group is the one taste call I cannot validate for you — `accordion = true` collapses the pill to just the NixOS snowflake and unfolds launcher/clipboard/screenshot on hover. It is the single most "top tier" motion in the design, but if reaching the clipboard button through a hover reveal annoys you, flip one boolean. SUPER+V / SUPER+SPACE should be bound regardless.
2) CONTROL-CENTER POSITION: I moved it from rightmost to leftmost (first member of `group:launch`) because a distro mark next to the power button reads as a settings gear, while at the far left it reads as a Start affordance. Reversible: move `"control-center"` out of the launch group's members and append it to `end`. If you do, also set `open_near_click_control_center` accordingly.
3) EMPTY-GROUP RENDERING: bar.cpp `attachWidgetsToSections` skips widgets whose `root() == nullptr` and falls back to `addSingleCapsule` when a run shrinks below 2 members, so a fully idle `group:media` (no MPRIS player + idle visualizer) should collapse to nothing rather than leaving a ghost pill. I read the code path but could not observe it running. Watch it once with nothing playing.
4) NVML: I proved `libnvidia-ml.so.1` does NOT resolve by soname in a clean env on deadPc (`python3 -c "ctypes.CDLL(...)"` → "cannot open shared object file"), and that noctalia dlopens it lazily by soname (system_monitor_service.cpp:873). The `LD_LIBRARY_PATH=/run/opengl-driver/lib` fix is standard NixOS practice and the library is present at that path, but I could not restart the unit to confirm the gpu stat lights up. If it stays "unavailable", drop `"gpu"` from the sys group.
5) `weather.effects` turned out to be animated GLSL shaders (Rain/Snow/Cloud/Fog/Sun/Stars, weather_tab.cpp:1194) drawn behind the Weather control-center tab header — genuinely fun, but confined to that tab. It is not a bar effect.
6) NUMERIC RANGES ARE NOT VALIDATED. `noctalia config validate` catches unknown settings (warning), unknown enum values (warning) and bad colour roles (ERROR → fails the HM build). It happily accepted `width = 5000` and `capsule_thickness = 3.0`. So role-name typos are build-safe; out-of-range numbers are silently clamped at runtime.
7) Out of my lane but found while verifying: `hl.bind(mainMod .. " + N", ... "panel-toggle notifications")` in config.nix is broken — `notifications` is not a panel id (valid ids: launcher, session, clipboard, wallpaper, control-center). The working form is `panel-toggle control-center notifications`. Also `vars.terminal = "kitty"` in flake/modules/constants.nix while ghostty is the real terminal.
