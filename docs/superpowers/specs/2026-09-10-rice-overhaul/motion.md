# Compositor feel

_Compositor feel — Hyprland 0.56.2 animations, blur, shadows, depth, rules (deadPc + deadConvertible)_

The Lua syntax question is settled, and the answer is good news: NO extraConfig gymnastics are needed. The HM renderer maps `settings.<name>` to `hl.<name>(...)` calls, one per list element, and an `{ _args = [...]; }` attrset to a multi-argument call — so `settings.curve`, `settings.animation`, `settings.window_rule` and `settings.layer_rule` all serialise correctly and declaratively. Better still, `importantPrefixes` already defaults to `["$" "bezier" "curve" "name" "output"]`, so `hl.curve()` is emitted before `hl.animation()` without any intervention. `animations.bezier` as a config key does not exist in 0.56 at all, so `hl.curve()` is mandatory, not optional. The design: a Material-3-derived curve family plus two springs, a 260ms/160ms in/out asymmetry, a 10-second looping borderangle over a seamless 3-stop gradient built live from Noctalia's palette, size-6/passes-3 blur with the popups switch finally on, a 22px offset elevation shadow in neutral black (deliberately NOT wallpaper-tinted), rounding 12 to match the Noctalia bar exactly, and the repo's first-ever window and layer rules. Two big blockers found: Noctalia's Hyprland template cannot install its own include line under Home Manager (read-only store symlink), so we must add `require("noctalia")` ourselves; and Noctalia's bar/panels are at opacity 1.0 with `transparency_mode = "solid"`, which makes every blur change in this domain invisible until that is fixed.

## Fatal problems flagged by the verifier

Nothing here breaks `nix flake check` or the build on its own — but three items break the SESSION or silently no-op if applied as literally written:

1. BUILD-BREAKING IF PASTED, not merged. Two snippets collide with attributes that already exist in the target files: `shell.panel` in modules/home-manager/windowManager/hyprland/noctalia.nix (the file already has `shell = { avatar_path; panel = { launcher_placement = "centered"; }; }`), and `general.border_size = 2` in modules/home-manager/windowManager/hyprland/config.nix. Both produce a Nix "attribute already defined" evaluation error. They must be edits to the existing blocks, not additions.

2. SILENT NO-OP, self-inflicted. The design's `pcall(require, "noctalia")` does not contain the literal substring `require("noctalia")` that Noctalia's apply.sh greps for (assets/templates/hyprland/apply.sh, apply_lua). The guard misses, the hook tries to append to a read-only /nix/store symlink, and `set -euo pipefail` aborts. Use `pcall(function() return require("noctalia") end)` so the literal string is present. Separately, ~/.config/hypr/noctalia.lua does not exist yet, so on the first render there is nothing for Hyprland's file watcher to have registered — budget one explicit `hyprctl reload`.

3. SILENT NO-OP, cross-domain. `programs.noctalia.checkConfig` defaults to true and runs `noctalia config validate` at build time, but I confirmed that command EXITS 0 on unknown keys and unknown enum values (it printed two warnings for the existing config and returned 0). So the build will never catch a fourth piece of dead syntax. The design's own bundled `builtin_ids = ["ghostty" "starship" "gtk3" "gtk4" ...]` is exactly that class of trap: those templates' post_hooks write through ~/.config/ghostty/config, ~/.config/starship.toml and ~/.config/gtk-3.0/gtk.css, all of which `ls -la` shows are read-only Home Manager store symlinks. Ship `builtin_ids = ["hyprland"]` only; taking those three files out of HM management is a prerequisite the colour-authority plan must own explicitly.

Also correct before building: the deadConvertible borderangle override needs `lib.mkAfter` (plain list merge puts the host entry FIRST, so the module's `loop` wins), and that host module does not currently bind `lib`.

## Verdicts

### [CONFIRMED] HM Lua renderer: settings.curve / animation / window_rule / layer_rule with _args

**Evidence:** /home/deadmade/nix-configuration/.direnv/flake-inputs/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules/services/window-managers/hyprland.nix:404-412 (importantPrefixes default = ["$" "bezier" "curve" "name" "output"]), :531-537 (renderArgs expands `_args` with concatMapStringsSep ", " toLua), :551-563 (renderCall/renderCalls emit one `hl.<name>(...)` per list element), :206-229 (settings option type + documented _args/_var semantics). Rendered live: `nix eval` over toLua produced `{["points"] = {{0.05,0.7},{0.1,1.0}}, ["type"]="bezier"}`, `{0, 6}` for `[0 6]`, and valid rule tables. All four functions exist on HL.API: hl.meta.lua:823 animation, :825 curve, :855 layer_rule, :862 window_rule, :824 config.

### [CONFIRMED] Curve library (emphasis / emphasisIn / overshot / almostLinear / quick + 2 springs)

**Evidence:** Only two beziers are built in: `hyprctl animations` on the running 0.56.2 ends with `beziers:` listing exactly `linear` (0,0 -> 1,1) and `default` (0,0.75 -> 0.15,1). Spring form verified verbatim in the shipped example /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/hypr/hyprland.lua: `hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })`, and bezier form `hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })`. `curve` is hoisted ahead of `animation` by importantPrefixes, so ordering is safe.

**Correction:**

No change. The y1=1.56 overshoot remains genuinely unverifiable from the shipped artifacts (no Hyprutils source in the tree); keep the designer's `spring = "bouncy"` fallback note.

### [CONFIRMED] Animation leaf names, speeds, and borderangle loop

**Evidence:** `hyprctl animations` leaf list on the live 0.56.2: border borderangle default fade fadeDim fadeDpms fadeGlow fadeIn fadeLayers fadeLayersIn fadeLayersOut fadeOut fadePopups fadePopupsIn fadePopupsOut fadeShadow fadeSwitch global glowangle __internal_fadeCTM layers layersIn layersOut monitorAdded shadowangle specialWorkspace specialWorkspaceIn specialWorkspaceOut windows windowsIn windowsMove windowsOut workspaces workspacesIn workspacesOut zoomFactor. Every leaf the design uses is present. borderangle block reads `overridden: 1 / bezier: default / enabled: 0`, confirming the stock preset disables it. Styles loop/once/popin/slide/slidevert/slidefade/slidefadevert/fade/gnomed all exist as exact standalone strings in /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/bin/.Hyprland-wrapped. Argument keys leaf/enabled/speed/bezier/spring/style verbatim in the shipped hyprland.lua.

**Correction:**

Two caveats the design does not carry: (1) `slidefade 20%` — I could not find any evidence in the shipped artifacts that the percentage is slide DISTANCE rather than fade amount; treat the rationale as unproven and the value as taste. (2) `animation` is emitted alphabetically BEFORE `config` (order is: curve, animation, config, gesture, layer_rule, window_rule), so `hl.animation(...)` runs before `hl.config({animations={enabled=true}})`. Harmless in practice but not what the design implies.

### [WRONG] deadConvertible override of borderangle to style="once"

**Evidence:** I evaluated the real merge with lib.evalModules against the module's own settingValueType. Two definitions of `settings.animation` CONCATENATE, but the host/later module's entries land FIRST: `{plain = {animation = [{leaf="B"},{leaf="A"}]}}` where B is the second module. Since Hyprland applies `hl.animation()` calls in file order, the module's `style = "loop"` would be emitted last and WIN, silently defeating the host override.

**Correction:**

In hosts/deadConvertible/home.nix use mkAfter, which I verified produces [A, B]:

```nix
wayland.windowManager.hyprland.settings.animation = lib.mkAfter [
  { leaf = "borderangle"; enabled = true; speed = 100; bezier = "linear"; style = "once"; }
];
```
(`lib` must be in the host module's argument set — deadConvertible/home.nix currently takes `{outputs, pkgs, config, ...}` and does NOT bind `lib`; add it.) The same mkAfter rule applies to any host-level `window_rule` addition, which matters because that change's whole premise is last-match-wins.

### [CONFIRMED] Blur: size 6 / passes 3 / popups true / noise / contrast / brightness / vibrancy / xray

**Evidence:** All keys present on HL.ConfigOpt.Decoration.Blur, hl.meta.lua:1403-1418 (enabled, size, passes, ignore_opacity, new_optimizations, xray, noise, contrast, brightness, vibrancy, vibrancy_darkness, special, popups, popups_ignorealpha, input_methods, input_methods_ignorealpha). Live values via hyprctl getoption on the running instance: blur:size int 8 set:false, blur:passes int 1 set:false, blur:popups bool false set:false, blur:noise 0.011700, blur:contrast 0.891600, blur:brightness 1.000000, blur:vibrancy 0.169600.

**Correction:**

Factual slip in the rationale only: the Noctalia bar is 60px tall, not 34px — `hyprctl layers` shows `noctalia-bar-default` at `xywh: 0 0 1920 60` on all three outputs. Does not change the recommended values.

### [CONFIRMED] Shadow: range 22, offset [0 6], scale 0.97, neutral black colour

**Evidence:** HL.ConfigOpt.Decoration.Shadow at hl.meta.lua:1388-1396 lists enabled/range/render_power/sharp/color/color_inactive/offset/scale. `offset` is HL.Vec2Like (hl.meta.lua:1056 and the alias at :396 = HL.Vec2|{x,y}|{number,number}|string), and toLua renders `[ 0 6 ]` as `{0, 6}` — I ran it. Live: shadow:range int 4 set:false, shadow:render_power int 3, shadow:sharp false, shadow:color `gradient data: 991e1e2e 0deg set: true` (Stylix), shadow:color_inactive `ffffffff set: false`. Noctalia's Hyprland template (.direnv/flake-inputs/h7afg…-source/assets/templates/hyprland/hyprland.lua) writes only general.col.* and group.*, never shadow — no conflict.

### [CONFIRMED] rounding 12 + rounding_power 2.4 (and restating border_size = 2)

**Evidence:** decoration.rounding / rounding_power exist (hl.meta.lua:1370-1371, and the shipped example sets `rounding = 10, rounding_power = 2`). Noctalia radii from `noctalia config export full` on the live shell: bar.default.radius = 12 with all four corner radii 12 (lines 46-50), launcher/clipboard/control-centre background_radius = 12.0 (lines 283/311/339), dock radius 16. Live decoration:rounding int 5 set:true, rounding_power float 2.0 set:false.

**Correction:**

Integration hazard, not an option error: `border_size = 2;` is ALREADY present in modules/home-manager/windowManager/hyprland/config.nix inside `settings.config.general`. Pasting the snippet's "stated so the choice is explicit" line as an addition produces a Nix duplicate-attribute error. Either drop that line or edit the existing one in place.

### [CONFIRMED] Opacity / dim block (dim_inactive false, dim_special 0.3, dim_around 0.5)

**Evidence:** active_opacity/inactive_opacity/fullscreen_opacity/dim_modal/dim_inactive/dim_strength/dim_special/dim_around all on HL.ConfigOpt.Decoration, hl.meta.lua:1368-1381. Live: active 1.0, inactive 1.0, fullscreen 1.0, dim_inactive bool false set:false, dim_strength 0.5, dim_special 0.2, dim_around 0.4, dim_modal bool true set:false.

### [WRONG] require("noctalia") handoff written as pcall(require, "noctalia")

**Evidence:** Noctalia's post_hook guard is a FIXED-STRING grep: assets/templates/hyprland/apply.sh, apply_lua(): `if ! grep -qF 'require("noctalia")' "$lua_config_file"; then printf '\n%s\n' "$include_line" >>"$lua_config_file"; fi`. The design's `local ok, noctalia = pcall(require, "noctalia")` does NOT contain the literal substring `require("noctalia")`, so the guard misses, the hook appends to ~/.config/hypr/hyprland.lua — which `ls -la` shows is a symlink into /nix/store/gx81c3j9gw0rm3rj508ypcypvgjxdqld-home-manager-files — and `set -euo pipefail` aborts the hook on EACCES. The design's own "post_hook will fail every render" prediction is therefore self-inflicted and avoidable.

**Correction:**

Write the require so the literal substring is present, which makes apply_lua() a genuine no-op:

```lua
-- Noctalia writes ~/.config/hypr/noctalia.lua; the literal string
-- require("noctalia") below is what its apply.sh greps for, so its
-- post_hook sees the include already present and never tries to append
-- to this read-only /nix/store file.
local ok, noctalia = pcall(function() return require("noctalia") end)
```
Second, unflagged gap: `ls ~/.config/hypr/noctalia.lua` -> No such file. On the first boot after enabling the template, the file does not exist when Hyprland evaluates the config, so `safeLuaRequire` cannot register a nonexistent path with the watcher and the auto-reload the design relies on cannot fire for that first render. Plan for one `hyprctl reload` (or a Noctalia user-template post_hook that runs it) after the first palette render, not just as a fallback.

### [CONFIRMED] Gradient border override via hl.config in extraConfig

**Evidence:** The template's returned table is verbatim as described — assets/templates/hyprland/hyprland.lua ends `return { colors = { primary, surface, on_surface, secondary, on_secondary, error, on_error }, apply_theme = apply_theme }`, and apply_theme() sets `general.col.active_border = primary` (flat), confirming the override is necessary. HL.Gradient alias at hl.meta.lua:398 (`string|{colors:string[], angle?:number}`), general.col.active_border typed string|HL.Gradient at :1078; the shipped example uses `{ colors = {...}, angle = 45 }`. extraConfig is rendered LAST (hyprland.nix:633-640: renderSettings, renderSubmaps, renderStartHook, then extraConfig), so it wins. Live: general:col.active_border `gradient data: ff89b4fa 0deg set: true`. Reload strings `[lua] file {} modified, reloading` and symbol `_ZL14safeLuaRequireP9lua_State` both present in .Hyprland-wrapped. require path resolution is proven by hyprsplit already loading from ~/.config/hypr/hyprsplit/.

### [WRONG] Enable Noctalia builtin template ids (hyprland + ghostty/starship/gtk3/gtk4/qt/btop)

**Evidence:** `hyprland` is a real id — `noctalia theme --list-templates` on the live 5.0.1 lists hyprland/ghostty/starship/gtk3/gtk4/qt/btop/kitty/…, and assets/templates/builtin.toml:168 has `[templates.hyprland]`. BUT the extra ids the design bundles in will fail: ghostty's post_hook (assets/templates/ghostty/apply.sh) does `cat "$tmp_file" > "$config_file"` / `echo "theme = noctalia" >> "$config_file"` against ~/.config/ghostty/config, and starship's does `cat "$tmp_file" > "$config_file"` against ~/.config/starship.toml. `ls -la` shows BOTH are symlinks into /nix/store/gx81c3j9gw0rm3rj508ypcypvgjxdqld-home-manager-files, as is ~/.config/gtk-3.0/gtk.css (the gtk3/gtk4 target). Every one of those writes is EACCES under `set -euo pipefail`.

**Correction:**

For this domain, add only the id that is actually needed:

```nix
templates = {
  enable_builtin_templates = true;
  builtin_ids = ["hyprland"];
};
```
ghostty / starship / gtk3 / gtk4 are NOT drop-in: they require first taking those files out of Home Manager's read-only management (e.g. `xdg.configFile` with a mutable copy, or `home.activation` seeding a writable file) before Noctalia can own their colours. That is a real blocker for the colour-authority domain, not a footnote — surface it to the orchestrator.

### [CONFIRMED] Layer rules for every Noctalia namespace; ignorezero removal

**Evidence:** Every namespace verified from source: bar.cpp:2395 `"noctalia-bar-" + barConfig.name`, panel_manager.cpp:878 and persistent_panel_host.cpp:220 `noctalia-panel`, panel_manager.cpp:1123 `noctalia-attached-panel`, panel_click_shield.cpp:163 `noctalia-panel-click-shield`, notification_toast.cpp:2065, osd_overlay.cpp:494, backdrop.cpp:252, wallpaper.cpp:1233, window_switcher.cpp:1056, overview_launcher_capture.cpp:144, screenshot_region_overlay.cpp:404, annotation_overlay.cpp:540. HL.LayerRuleSpec at hl.meta.lua:555-569 has exactly above_lock, animation, blur, blur_popups, dim_around, enabled, ignore_alpha, match, name, no_anim, no_screen_share, order, xray — `ignorezero`/`ignore_zero` appear nowhere in the stub or in .Hyprland-wrapped, so the design's correction is right. NOCTALIA_BLUR_TRACE is real (src/wayland/surface.cpp:85, layer_surface.cpp:21); the protocol path is real (surface.cpp:721 ext_background_effect_surface_v1_set_blur_region; bar.cpp:3168 applyBarCompositorBlur, :3199 setBlurRegion) and Hyprland implements it (ext_background_effect_manager_v1_interface in .Hyprland-wrapped). Noctalia's lockscreen is ext-session-lock (wayland_connection.h:207, lockscreen/lock_surface.h:23-24), so `above_lock` on the OSD is the right instrument.

**Correction:**

Only `animation = "slide top"` / `"popin 90%"` as layer-rule VALUES are unproven — the stub types the field as a bare `string` and I found no parser evidence for the direction suffix. Plausible (the styles all exist as strings) but flag it: if a panel does not animate, that value is the first suspect.

### [CONFIRMED] Noctalia opacity precondition (bar background_opacity 0.72, transparency_mode glass)

**Evidence:** `noctalia config export full` on the live shell: line 22 `background_opacity = 1.0` under [bar.default], line 504 `transparency_mode = "solid"` under [shell.panel]. Enum strings verified at src/config/config_types.h:866-870 kPanelTransparencyModes = {solid, soft, glass}, bound at src/config/schema/config_schema.cpp:1314. Alphas at src/config/config_types.cpp:204-214 detachedPanelBackgroundOpacityForTransparencyMode: Solid 1.0, Soft 0.80, Glass 0.55 — exactly as claimed.

**Correction:**

The Nix as written will NOT compile into the existing file. modules/home-manager/windowManager/hyprland/noctalia.nix already contains `shell = { avatar_path = ...; panel = { launcher_placement = "centered"; }; };`. Adding a second `shell.panel = { transparency_mode = ... }` in the same attrset is a Nix duplicate-attribute error. Merge into the existing block, and fix the dead v4 value in the same edit:

```nix
shell = {
  avatar_path = "/home/${vars.username}/.face";
  panel = {
    launcher_placement = "floating";   # was "centered" — rejected by v5
    launcher_position = "center";
    transparency_mode = "glass";       # solid | soft | glass
  };
};
```
I confirmed the v5 spelling from the live export (lines 491-492: launcher_placement = "floating", launcher_position = "center") and the rejection from `noctalia config validate`, which prints `WARN … launcher_placement: unknown value "centered"` and still EXITS 0. That matters: programs.noctalia.checkConfig defaults true and runs `noctalia config validate` at build time (.direnv/flake-inputs/h7afg…-source/nix/home-module.nix:127-134), so a bad enum will NOT fail the build — it fails silently at runtime, exactly the failure mode the brief warns about.

### [UNCERTAIN] Window rules: property names, match keys, ordering claim

**Evidence:** HL.WindowRuleSpec in the stub (hl.meta.lua:597-601) declares ONLY enabled/match/name — the rule properties are not enumerated anywhere in the shipped type info, so the design's evidence is reduced to `strings` over the binary. I re-ran that: suppress_event, idle_inhibit, opacity_override, opacity_inactive, opacity_fullscreen, render_unfocused, no_blur, immediate, dim_around, no_focus, nearest_neighbor, keep_aspect_ratio, no_screen_share, persistent_size, initial_class, fullscreen_state all present as exact standalone strings. idle_inhibit values none/always/focus/fullscreen/fullscreenoutput/maximize/activatefocus all present. Live app-ids from `hyprctl clients`: com.mitchellh.ghostty, dev.zed.Zed, librewolf, Spotify — the ghostty and media patterns are right. But a string in a 19MB binary is not proof of a Lua rule key, and one match key is demonstrably off-spec.

**Correction:**

The match key is `pin`, not `pinned`, in the only proven-good example: the shipped /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/hypr/hyprland.lua writes `match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }`. Both `pin` and `pinned` exist as binary strings, so this may be tolerated, but copy the example verbatim rather than guessing:

```nix
{ name = "fix-xwayland-drags";
  match = { class = "^$"; title = "^$"; xwayland = true; float = true; fullscreen = false; pin = false; };
  no_focus = true; }
```
Also: blueman's app-id could not be checked (not running); do not ship `^([.]?blueman-manager(-wrapped)?)$` untested. And the "last match wins, the Nix list preserves order" claim holds only WITHIN one definition — see the mkAfter finding.

### [CONFIRMED] misc/render/NVIDIA: vfr and explicit_sync absent; direct_scanout and ctm_animation

**Evidence:** `hyprctl getoption misc:vfr` -> `no such option`; `hyprctl getoption render:explicit_sync` -> `no such option`, both on the running 0.56.2. HL.ConfigOpt.Render in hl.meta.lua has no vfr and no explicit_sync key; it does have direct_scanout, ctm_animation, new_render_scheduling. HL.ConfigOpt.Misc has background_color (string) and render_unfocused_fps. Live: render:direct_scanout int 0 set:false, render:ctm_animation int 2 set:false, general:allow_tearing bool false set:false, misc:render_unfocused_fps int 15, misc:background_color int 4280163886 set:true (Stylix), cursor:no_hardware_cursors int 2 set:false. `hyprctl monitors` confirms `directScanoutBlockedBy: user settings,missing candidate`, `solitaryBlockedBy: windowed mode,missing candidate`, `vrr: false`, `currentFormat: XRGB8888` on all three outputs.

**Correction:**

The design's own uncertainty is correctly stated and I could not reduce it: the 0/1/2 semantics of direct_scanout and ctm_animation are typed `integer|boolean` with no enum evidence anywhere in the stub or binary. Add one hardware caveat the design omits: with the always-present full-width `noctalia-bar-default` top layer, solitary can only ever occur under a fullscreen window, so direct_scanout = 1 buys nothing outside fullscreen games — and on NVIDIA proprietary 595.99.02 both direct scanout and allow_tearing are the two settings most likely to produce a black or flickering output. Ship them last, separately, and per CLAUDE.md use `nixos-rebuild boot` + reboot on this nix-mineral host.

### [CONFIRMED] Demote stylix.targets.hyprland (kills colours + the stray hyprpaper layer)

**Evidence:** .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/hyprland/hm.nix sets decoration.shadow.color, general."col.active_border"/"col.inactive_border", the group + groupbar colour block and misc.background_color (wrapped in `{ config = colorSettings; }` for configType=="lua"), and a second block gated on `cfg.hyprpaper.enable` (autoEnable = image != null) that sets `services.hyprpaper.enable = true`. mk-target.nix:326 confirms `config = lib.mkIf (config.stylix.enable && cfg.enable) (...)`, so one switch kills both blocks. Live proof of the duplicate daemon: `hyprctl layers` shows namespace hyprpaper (pid 4473) AND noctalia-wallpaper (pid 4475) on HDMI-A-1, DP-2 and DP-3; ~/.config/hypr/hyprpaper.conf is an HM store symlink. `grep -rn hyprpaper --include='*.nix'` over the repo (excluding .direnv) returns nothing.

**Correction:**

The design's risk note is resolvable and can be dropped: stylix's hyprland target ships ONLY hm.nix (`ls .direnv/flake-inputs/95awhm…-source/modules/hyprland/` -> hm.nix, meta.nix, testbeds — no nixos.nix), so modules/nixos/desktop/stylix.nix needs no matching change. Note the one thing that goes away with it: hm.nix's `config.misc.disable_hyprland_logo = true`. The repo already sets that itself in config.nix, so nothing is lost.

### [CONFIRMED] Remove ghostty background-blur as a Hyprland no-op

**Evidence:** `strings` over /nix/store/444h3sfs9fk7fi8hif6wgg11rkc24vjd-ghostty-1.3.1/bin/.ghostty-wrapped: org_kde_kwin_blur, org_kde_kwin_blur_manager, _KDE_NET_WM_BLUR_BEHIND_REGION, plus the man-page text "Warning: the exact blur intensity is _ignored_ under KDE Plasma" and the KWin "Blur" plugin checkbox instructions — KDE/KWin protocol only, no ext_background_effect. `strings` over .Hyprland-wrapped: zero matches for kde_kwin_blur / kwin_blur / blur_manager; the only blur protocol present is ext_background_effect_manager_v1 / ext_background_effect_surface_v1. Current modules/home-manager/terminal/ghostty.nix:22 has `background-blur = 10;`.

**Correction:**

The replacement snippet silently drops nothing functional, but note ghostty.nix's `settings` block also carries the `# Font size (family is provided by Stylix)…` comment above font-size; keep it, and keep `enableZshIntegration`/`package`/`keybind` untouched — the snippet shows an abridged block that should not be pasted over the file wholesale.

## Proposed changes

### 1. (high) Curve library: Material-3 emphasis pair, an overshoot, and two springs

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Only `default` and `linear` are built into Hyprland 0.56.2 (I grepped the unwrapped binary for standalone curve-name strings: exactly those two). `easeOutQuint` and friends exist only in the shipped example config, so every curve must be declared. `settings.curve` renders as `hl.curve(name, spec)` because the HM renderer expands `_args` into a comma-separated argument list, and `curve` matches the default `importantPrefixes` so it is emitted before `settings.animation`. Control points: `emphasis` = (0.05,0.7),(0.1,1.0) is Google's Material-3 emphasized-decelerate — a very steep initial slope with a long flat approach, which is the canonical 'expensive software' settle. `emphasisIn` = (0.3,0.0),(0.8,0.15) is its accelerate twin: nearly flat for the first third then a hard exit, correct for things leaving because you should never wait on a dismissal. `overshot` = (0.34,1.56),(0.64,1.0) is easeOutBack; y1 = 1.56 > 1 pushes the value ~10% past target before settling, which on a `popin` style means the window scales past 100% and snaps back — the actual 'pop'. `almostLinear` and `quick` are carried over from stock because they are correct for opacity, where any easing reads as a flicker. Springs: damping ratio is c/(2*sqrt(k*m)). `bouncy` = 26/(2*sqrt(330)) = 0.716, underdamped with one visible ~5% overshoot; settling time 4/(zeta*omega0) = 4/(0.716*18.17) = 0.31s. `settle` = 32/(2*sqrt(420)) = 0.781, omega0 = 20.49, settles in 0.25s — tighter, for window drags where bounce would feel imprecise. Stock `easy` is 0.785/238 for comparison, so `bouncy` is deliberately a touch looser and faster.

**Verified against:** /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/hypr/hyprland.lua (Hyprland's own shipped example: `hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })`); .direnv/flake-inputs/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules/services/window-managers/hyprland.nix lines 531-580 (renderArgs/_args/renderCalls) and 404-412 (importantPrefixes default). I simulated the exact renderer over this snippet with `nix eval` and it emits `hl.curve("emphasis", { ["points"] = { {0.05,0.7}, {0.1,1.0} }, ["type"] = "bezier" })`.

**Risk:** y1 = 1.56 on `overshot` relies on Hyprland not clamping bezier Y to [0,1]. Hyprutils CBezierCurve::getYForPoint is a generic evaluator and overshoot beziers are common in the wild, but if the pop looks clipped rather than springy, drop y1 to 1.25 or switch windowsIn to `spring = "bouncy"` instead.

```nix
# NEW top-level key inside wayland.windowManager.hyprland.settings
# (sibling of `config`, `gesture`, `monitor` — NOT inside `config`).
curve = [
  { _args = [ "emphasis"     { type = "bezier"; points = [ [0.05 0.7] [0.1 1.0] ]; } ]; }
  { _args = [ "emphasisIn"   { type = "bezier"; points = [ [0.3 0.0] [0.8 0.15] ]; } ]; }
  { _args = [ "overshot"     { type = "bezier"; points = [ [0.34 1.56] [0.64 1.0] ]; } ]; }
  { _args = [ "almostLinear" { type = "bezier"; points = [ [0.5 0.5] [0.75 1.0] ]; } ]; }
  { _args = [ "quick"        { type = "bezier"; points = [ [0.15 0.0] [0.1 1.0] ]; } ]; }
  { _args = [ "bouncy" { type = "spring"; mass = 1.0; stiffness = 330.0; dampening = 26.0; } ]; }
  { _args = [ "settle" { type = "spring"; mass = 1.0; stiffness = 420.0; dampening = 32.0; } ]; }
];
```

### 2. (high) Full animation set: 260ms in / 160ms out, spring motion, and a 10s looping borderangle

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Speed is in deciseconds (1 = 100ms). On the refresh-rate question: the 60Hz side panels set the FLOOR, not the 240Hz centre panel the ceiling. At 60Hz a 100ms animation is 6 frames, which is too few for an overshoot to read as an overshoot rather than a glitch; below ~120ms motion looks stepped. At 240Hz the same curve simply gets 4x the samples and looks smoother for free. So do NOT shorten globally because of the 240Hz panel — tune for 60Hz legibility and the fast panel is a bonus. The usable window is 130-260ms for primary transitions: 2.6ds = 16 frames at 60Hz, 62 at 240Hz. Asymmetry: `windowsIn` 2.6 vs `windowsOut` 1.6 — an exit at ~60% of the entry duration is the standard M3 ratio, because you have already decided to close and waiting is pure latency. `popin 92%` instead of the stock 87%: on 1920px-wide monitors 87% scales from 1670px, a 250px jump that reads as a zoom; 92% (1766px) reads as materialising, and the `overshot` curve supplies the pop that the smaller scale gives up. `workspaces` uses `slidefade 20%` at 3.0ds — the percentage is slide DISTANCE, not opacity, so the workspace moves only 20% of the monitor while cross-fading; a full-width slide across 1920px in 300ms is 6400px/s and reads as a lurch, while a 384px slide preserves the directional cue without the travel. hyprsplit makes workspaces per-monitor so the slide stays on one screen. `borderangle` at speed 100 with style `loop` = one full 360deg rotation per 10 seconds (36 deg/s): fast enough to be alive, slow enough to be ambient — at 5s it reads as gamer RGB. This is the leaf the stock preset explicitly DISABLES (`hyprctl animations` shows borderangle overridden:1 enabled:0), which is why the gradient work in the borders change is inert without it.

**Verified against:** Leaf names taken verbatim from `hyprctl animations` on the running 0.56.2 (full list: border borderangle default fade fadeDim fadeDpms fadeGlow fadeIn fadeLayers fadeLayersIn fadeLayersOut fadeOut fadePopups fadePopupsIn fadePopupsOut fadeShadow fadeSwitch global glowangle layers layersIn layersOut monitorAdded shadowangle specialWorkspace specialWorkspaceIn specialWorkspaceOut windows windowsIn windowsMove windowsOut workspaces workspacesIn workspacesOut zoomFactor). Argument keys leaf/enabled/speed/bezier/spring/style confirmed as standalone strings in the unwrapped binary and in Hyprland's shipped hyprland.lua. Styles `loop`, `once`, `popin`, `slide`, `slidevert`, `slidefade`, `slidefadevert`, `fade`, `gnomed` all confirmed as exact strings in /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/bin/.Hyprland-wrapped.

**Risk:** `borderangle` with `loop` repaints the border region every frame forever. On deadPc (RTX 3070) that is free; on deadConvertible it is a measurable battery cost and it will keep the GPU out of idle. Recommend overriding to `style = "once"` in hosts/deadConvertible/home.nix. Also: with a spring curve, `speed` may be ignored in favour of the spring physics — Hyprland's own default supplies both, so supplying both is safe, but do not tune `windows` by changing 2.4.

```nix
# NEW top-level key inside settings, sibling of `curve`.
animation = [
  { leaf = "global";           enabled = true; speed = 10;  bezier = "default"; }
  { leaf = "windows";          enabled = true; speed = 2.4; spring = "bouncy"; }
  { leaf = "windowsIn";        enabled = true; speed = 2.6; bezier = "overshot";   style = "popin 92%"; }
  { leaf = "windowsOut";       enabled = true; speed = 1.6; bezier = "emphasisIn"; style = "popin 92%"; }
  { leaf = "windowsMove";      enabled = true; speed = 2.2; spring = "settle"; }
  { leaf = "border";           enabled = true; speed = 2.2; bezier = "emphasis"; }
  { leaf = "borderangle";      enabled = true; speed = 100; bezier = "linear";     style = "loop"; }
  { leaf = "fade";             enabled = true; speed = 2.4; bezier = "almostLinear"; }
  { leaf = "fadeIn";           enabled = true; speed = 1.5; bezier = "almostLinear"; }
  { leaf = "fadeOut";          enabled = true; speed = 1.2; bezier = "almostLinear"; }
  { leaf = "fadePopups";       enabled = true; speed = 1.2; bezier = "quick"; }
  { leaf = "layers";           enabled = true; speed = 2.4; bezier = "emphasis"; }
  { leaf = "layersIn";         enabled = true; speed = 2.6; bezier = "emphasis";   style = "fade"; }
  { leaf = "layersOut";        enabled = true; speed = 1.7; bezier = "emphasisIn"; style = "fade"; }
  { leaf = "fadeLayersIn";     enabled = true; speed = 1.6; bezier = "almostLinear"; }
  { leaf = "fadeLayersOut";    enabled = true; speed = 1.3; bezier = "almostLinear"; }
  { leaf = "workspaces";       enabled = true; speed = 3.0; bezier = "emphasis";   style = "slidefade 20%"; }
  { leaf = "workspacesIn";     enabled = true; speed = 3.0; bezier = "emphasis";   style = "slidefade 20%"; }
  { leaf = "workspacesOut";    enabled = true; speed = 2.4; bezier = "emphasisIn"; style = "slidefade 20%"; }
  { leaf = "specialWorkspace"; enabled = true; speed = 2.6; bezier = "emphasis";   style = "slidevert"; }
  { leaf = "zoomFactor";       enabled = true; speed = 1.8; bezier = "quick"; }
];
```

### 3. (high) Premium blur: size 6 / passes 3, and turn on popups

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Correcting the premise: passes is NOT exponentially more expensive than size. Hyprland uses dual-Kawase, where each pass runs at a quarter of the previous pass's resolution, so total fragment work converges to ~1.33x the first pass per direction (~2.7x overall) no matter how many passes. `size` sets the sample offset, not the tap count, so it is nearly free. Effective radius is roughly size * 2^passes. size 6 / passes 3 gives ~48px — enough that the 34px-thick bar fully dissolves the wallpaper detail behind it instead of showing a smeared but recognisable image. passes 4 (~96px radius) pulls colour from too far away and turns the bar into a flat wash, losing the 'you can see through it' quality; 3 is a taste ceiling, not a GPU one. Cost on a 3070 at 1080p per damaged region: pass 1 at 1920x1080, pass 2 at 960x540, pass 3 at 480x270 — well under 1ms, and blur only runs behind translucent surfaces. noise 0.02 (from 0.0117): `hyprctl monitors` reports currentFormat XRGB8888, i.e. 8-bit, and a 48px blur over a smooth wallpaper gradient bands visibly at 8-bit; 0.02 grain dithers it away and is invisible at arm's length, while 0.05+ looks dirty. contrast 0.95 (from 0.8916): stock flattens the backdrop, which is exactly wrong when Noctalia is deriving the entire palette FROM that wallpaper — you want the chrome to visibly belong to the image. brightness 0.85 with vibrancy 0.25 and vibrancy_darkness 0.15: the 15% dim guarantees text contrast on the bar regardless of how bright the current wallpaper is, and the vibrancy boost stops that dim from turning the glass grey. `popups = true` is the single highest-value line here — it is currently false, which is precisely why every GTK/Qt context menu, dropdown and tooltip reads flat.

**Verified against:** Key names from the HL.ConfigValueTypes block of /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/hypr/stubs/hl.meta.lua lines 1019-1034 (decoration.blur.brightness/contrast/enabled/ignore_opacity/input_methods/input_methods_ignorealpha/new_optimizations/noise/passes/popups/popups_ignorealpha/size/special/vibrancy/vibrancy_darkness/xray). Current live values read with `hyprctl getoption` on the running session: size 8, passes 1, noise 0.0117, contrast 0.8916, brightness 1.0, vibrancy 0.1696, vibrancy_darkness 0.0, popups false, xray false, new_optimizations true, ignore_opacity true.

**Risk:** `xray = false` is deliberate. xray makes blur sample only the wallpaper and ignore windows underneath — cheaper and it keeps a full-width bar visually anchored to the wallpaper it derives its colours from, but a floating panel over a window would then show wallpaper, which reads as a rendering bug. If the 60Hz side panels ever stutter, `xray = true` as a per-layer rule on `^noctalia-bar-` only is the correct escape hatch, not the global switch.

```nix
# inside settings.config.decoration
blur = {
  enabled = true;
  size = 6;
  passes = 3;
  noise = 0.02;
  contrast = 0.95;
  brightness = 0.85;
  vibrancy = 0.25;
  vibrancy_darkness = 0.15;
  popups = true;              # was false -> this is why menus look flat
  popups_ignorealpha = 0.2;   # default, stated for clarity
  input_methods = true;
  special = true;
  xray = false;               # see risk note
  # new_optimizations and ignore_opacity are already true by default in 0.56.
};
```

### 4. (high) Real elevation shadows: range 22, downward offset, neutral black — NOT wallpaper-tinted

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** range 4 at 1080p is roughly invisible. Shadow spread should scale with corner radius: with rounding 12 and gaps_out 8, a 22px range extends ~14px past the gap so adjacent tiled windows' shadows just overlap, which is what produces 'cards on a surface' instead of 'windows with halos'. 22 is also ~2x the corner radius, the standard elevation-shadow ratio (Material elevation 6dp uses ~2x radius blur). Above ~30 at 1080p it becomes a 2009 drop-shadow filter. offset [0 6] gives a downward-only cast implying a light source above — the universal convention and the fastest read of depth; 6px is 0.27x the range, subtle enough not to look pasted on. scale 0.97 shrinks the shadow geometry to 97% of the window so it does not peek out symmetrically at the top; combined with the +6 y-offset the top edge is nearly shadowless and the bottom pronounced, which is the specific trick that separates an elevation shadow from a glow. render_power 3 kept: it is the falloff exponent, and 3 with range 22 gives a soft wide falloff, whereas 4 concentrates it near the window and looks heavy. ON COLOUR: Stylix currently owns this (`rgba(1e1e2e99)`) and once the Stylix hyprland target is disabled nobody sets it, falling back to Hyprland's `0xee1a1a1a` — 93% alpha, far too heavy at range 22. Set it ourselves, statically, and deliberately do NOT hand it to Noctalia: a shadow is the absence of light, not a brand colour. A wallpaper-derived shadow tint would make shadows drift purple then orange as the wallpaper rotates every 30 minutes, which reads as a bug rather than a theme. 0x4d = 30% black over 22px is clearly visible separation without mud (compare: stock 93% over 4px is a hard dark line). color_inactive at 20% is the depth cue that replaces dim_inactive — unfocused windows sit lower rather than being greyed out.

**Verified against:** decoration.shadow.color / color_inactive / enabled / offset / range / render_power / scale / sharp all present in hl.meta.lua lines 1053-1060, with offset typed HL.Vec2Like = HL.Vec2|{x,y}|{number,number}|string (line ~397). Live defaults confirmed via `hyprctl getoption`: range 4, render_power 3, sharp false, scale 1.0, color `991e1e2e set: true` (Stylix), color_inactive `ffffffff set: false`. Noctalia's builtin Hyprland template (assets/templates/hyprland/hyprland.lua) touches only general.col.* and group.* — it never writes shadow colour, so there is no conflict.

**Risk:** `offset = [ 0 6 ]` renders as Lua `{0, 6}`, which I confirmed by running the HM renderer over it with `nix eval`. If Hyprland rejects the table form for Vec2Like, the string form `offset = "0 6"` is the documented fallback.

```nix
# inside settings.config.decoration
shadow = {
  enabled = true;
  range = 22;
  render_power = 3;
  offset = [ 0 6 ];               # HL.Vec2Like accepts {number, number}
  scale = 0.97;
  sharp = false;
  color = "rgba(0000004d)";         # neutral black 30% — intentionally NOT themed
  color_inactive = "rgba(00000033)"; # 20% — unfocused windows sit lower
};
```

### 5. (medium) Rounding 12 to match the Noctalia bar exactly, plus rounding_power 2.4 for squircle corners

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** 12 is not an aesthetic guess — `noctalia config export full` reports `bar.default.radius = 12` (and radius_top_left/top_right/bottom_left/bottom_right all 12), and the launcher/clipboard/control-centre card `background_radius` is also 12.0. The bar is the one piece of chrome always on screen; when a maximized window's corners differ from the bar's, the eye reads two unrelated design systems sharing a display. 12 is also large enough at 1080p (0.6% of width) to read as intentional and small enough that a 4px-gap dwindle layout does not show wallpaper wedges between tiles. On rounding_power: Hyprland generates the corner from the superellipse |x/r|^p + |y/r|^p = 1. p = 2.0 is a true circular quarter-arc. Raising p flattens the middle of the curve and tightens the transition into the straight edge — that IS the squircle / Apple continuous-corner geometry; p to infinity approaches a square corner. iOS continuous corners sit around p = 4-5 in a pure superellipse, but at r = 12 there are only ~12 pixels of arc to work with, so a high p has nothing left to show and just straightens. 2.4 gives a visible flattening (the corner hugs the edge longer) while keeping the curvature legible at 12px. If the radius ever goes to 16+, 2.8-3.0 becomes the right value. border_size stays 2: the border is drawn inside the rounding radius, and 3px at r=12 starts eating the corner arc; 2px is still enough to carry a visible gradient across three monitors without shouting.

**Verified against:** decoration.rounding (integer|boolean) and decoration.rounding_power (number|boolean) at hl.meta.lua lines 1050-1051; Hyprland's shipped example sets both together (`rounding = 10, rounding_power = 2`). Noctalia radii read from `noctalia config export full` on the live shell: bar.default.radius = 12, dock radius = 16 (dock disabled), launcher/clipboard/control-centre background_radius = 12.0.

**Risk:** None functionally. If 12 feels too soft on a maximized editor, 10 keeps the family relationship; do not drop below 8 or the bar/window mismatch returns.

```nix
# inside settings.config.decoration
rounding = 12;        # was 5; matches noctalia bar.default.radius = 12 exactly
rounding_power = 2.4; # superellipse exponent: 2.0 = circular arc, higher = squircle

# inside settings.config.general — unchanged, stated so the choice is explicit
border_size = 2;
```

### 6. (medium) Opacity and depth: leave global opacity alone, and dim_inactive does NOT earn its place on three monitors

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Direct answer to the dim_inactive question: no. On one monitor, dim_inactive tells you where focus is. On a 5760x1080 canvas it dims two entire monitors' worth of content you are actively reading — it is a single-monitor idiom that fights this workflow. The focus signal is already delivered twice over by the animated gradient border and by shadow.color_inactive (20%) versus color (30%), so unfocused windows sit lower rather than going grey. Same reasoning kills global active_opacity/inactive_opacity: ghostty already renders at 0.8 via stylix.opacity.terminal, so a global 0.95 would compound to 0.76 and, worse, would apply to Librewolf and video where translucency actively degrades text antialiasing over a blurred backdrop. Per-app windowrules are the right instrument (see the window-rule change). dim_special 0.3 (from 0.2) is kept and raised because the special workspace genuinely IS a modal context — 0.3 over the blurred backdrop says 'you are somewhere else' clearly. dim_around 0.5 (from 0.4) only applies to surfaces carrying the dim_around rule, which here is only the polkit prompt; 0.5 rather than 0.4 so the compositor's modal dim clearly dominates if Noctalia's own backdrop is also enabled. dim_modal is already true by default in 0.56 (`hyprctl getoption decoration:dim_modal` -> bool: true set: false), so modal child dialogs already dim their parent for free.

**Verified against:** decoration.active_opacity / inactive_opacity / fullscreen_opacity / dim_around / dim_inactive / dim_modal / dim_special / dim_strength all present at hl.meta.lua lines 1018, 1036-1041, 1047. Live values via `hyprctl getoption`: active 1.0, inactive 1.0, fullscreen 1.0, dim_inactive false, dim_strength 0.5, dim_special 0.2, dim_around 0.4, dim_modal true.

**Risk:** If the user later wants a focus dim anyway, prefer `dim_inactive = true; dim_strength = 0.15;` — 0.5 is the stock strength and is far too aggressive across three screens.

```nix
# inside settings.config.decoration
active_opacity     = 1.0;   # deliberate: ghostty's 0.8 comes from stylix.opacity.terminal
inactive_opacity   = 1.0;   # deliberate: do not grey out two monitors you are reading
fullscreen_opacity = 1.0;
dim_inactive       = false; # does not earn its place on a 3-monitor 5760x1080 canvas
dim_special        = 0.3;   # the special workspace IS a modal context
dim_around         = 0.5;   # only fires on surfaces carrying the dim_around rule
```

### 7. (high) Animated gradient borders driven live by Noctalia's palette (and the include line Noctalia cannot write)

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Two defects found here. (1) Noctalia's Hyprland template runs `apply.sh apply`, whose `apply_lua()` greps ~/.config/hypr/hyprland.lua and APPENDS `require("noctalia").apply_theme()` if missing. Under Home Manager that path is a read-only symlink into the nix store, so the append fails and `set -euo pipefail` aborts the hook. The rendered ~/.config/hypr/noctalia.lua is still written (rendering happens before the post_hook), so the only thing lost is the include — we must add it ourselves. (2) `apply_theme()` sets `general.col.active_border` to a FLAT primary colour, which would silently destroy any gradient. Fix: call `apply_theme()` first for the group/groupbar work it does well, then override active_border with a gradient built from the module's own exported `colors` table — the template returns `{ colors = { primary, surface, on_surface, secondary, on_secondary, error, on_error }, apply_theme = ... }`, so the palette is right there. The 3-stop `primary, secondary, primary` is not decoration: a seamless loop requires the first and last stop to be identical, otherwise `borderangle` with `loop` sweeps a hard colour seam around every window once per 10 seconds. angle 45 puts the gradient axis diagonal so a wide window shows both stops. Reload behaviour: Hyprland 0.56.2 ships its own `safeLuaRequire` and logs `[lua] file {} modified, reloading` — required Lua files are registered with the config watcher, so when Noctalia re-renders noctalia.lua on a palette change Hyprland reloads by itself; no hyprctl hook needed. This must go in extraConfig (it is dynamic Lua), and extraConfig is appended last, so it correctly wins over anything in settings.config.

**Verified against:** Template source read in full at .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/assets/templates/hyprland/{apply.sh,hyprland.lua}; the returned module table and apply_theme body are verbatim from that file. Gradient form `{ colors = {...}, angle = 45 }` is HL.Gradient (hl.meta.lua: `---@alias HL.Gradient string|{colors:string[], angle?:number}`, and general.col.active_border is typed `string|HL.Gradient` at line 1078) and appears in Hyprland's own shipped example. `safeLuaRequire` and the string `[lua] file {} modified, reloading` are both present in /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/bin/.Hyprland-wrapped. Current live value `hyprctl getoption general:col.active_border` -> `gradient data: ff89b4fa 0deg set: true` (Stylix).

**Risk:** I verified the auto-reload strings in the binary but did not observe a live palette-change reload. If it does not fire, `hyprctl reload` appended to a Noctalia user template's post_hook is the fallback. Also note the consequence: with theme.source = "wallpaper" and a 1800s rotation, Hyprland does a full config reload every 30 minutes. That is fine here specifically because autostart uses `hl.on("hyprland.start", ...)` rather than `exec-once`, so librewolf is NOT relaunched on reload — a real advantage of the Lua form.

```nix
# in extraConfig, at the very top of the raw-Lua block
''
  -- Noctalia colour handoff. Noctalia's template tries to append this require
  -- line to hyprland.lua itself; that fails under Home Manager because the file
  -- is a read-only /nix/store symlink, so we do it here. Hyprland 0.56's
  -- safeLuaRequire registers required files with the config watcher, so a
  -- palette change rewrites noctalia.lua and Hyprland reloads on its own.
  local ok, noctalia = pcall(require, "noctalia")
  if ok and type(noctalia) == "table" and noctalia.colors then
    noctalia.apply_theme() -- group / groupbar / inactive colours
    -- apply_theme() sets a FLAT active border; replace it with a seamless
    -- 3-stop gradient (first stop == last stop, so `borderangle loop` has no seam).
    hl.config({
      general = {
        col = {
          active_border = {
            colors = { noctalia.colors.primary, noctalia.colors.secondary, noctalia.colors.primary },
            angle = 45,
          },
          inactive_border = noctalia.colors.surface,
        },
      },
    })
  else
    -- First boot, or template disabled: static fallback so the config still loads.
    hl.config({
      general = {
        col = {
          active_border = { colors = { "rgb(89b4fa)", "rgb(cba6f7)", "rgb(89b4fa)" }, angle = 45 },
          inactive_border = "rgb(45475a)",
        },
      },
    })
  end
''
```

### 8. (high) Enable Noctalia's builtin `hyprland` template (precondition for the gradient)

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `theme.templates.builtin_ids` is currently `["kitty"]`, and kitty is disabled in this config (programs.kitty.enable = false), so the template engine is presently doing nothing useful at all. Without `hyprland` in the list, ~/.config/hypr/noctalia.lua is never rendered and the require in the previous change always takes the static fallback branch. `hyprland` is the exact catalogue id, confirmed both in assets/templates/builtin.toml (`[catalog.hyprland]` / `[templates.hyprland]`) and in the live `noctalia theme --list-templates` output. Adding `ghostty` and `starship` here is also the mechanism by which Noctalia takes over the terminal and prompt colours per the colour-authority decision, and both are real builtin ids in the same list.

**Verified against:** `noctalia theme --list-templates` run against the live 5.0.1 shell: ids hyprland, ghostty, starship, gtk3, gtk4, qt, btop, kitty, alacritty, foot, wezterm, cava, emacs, helix, kcolorscheme, labwc, mango, niri, scroll, sway, umbriel. Cross-checked against .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/assets/templates/builtin.toml.

**Risk:** The `hyprland` template's post_hook WILL fail every render (read-only hyprland.lua) and Noctalia will log a hook error. That is cosmetic — the rendered file is written first — but it is noise in the log and worth a comment in the Nix so nobody chases it later. Only the hyprland id is strictly in this domain; ghostty/starship/gtk/qt/btop belong to the colour-authority work and are listed here only so the block is complete.

```nix
# programs.noctalia.settings.theme.templates
templates = {
  enable_builtin_templates = true;
  builtin_ids = [
    "hyprland"   # renders ~/.config/hypr/noctalia.lua (border/group colours)
    "ghostty"
    "starship"
    "gtk3"
    "gtk4"
    "qt"
    "btop"
  ];
};
```

### 9. (high) Layer rules: per-edge panel animations for every Noctalia surface (the repo has zero today)

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Every namespace here is read from an exact `.nameSpace =` assignment in the Noctalia 5.0.1 source, not guessed. Directions are matched to each surface's configured anchor from the live `noctalia config export full`: the bar is position "top"; attached panels hang off the top bar; notification.position = "top_right"; osd.position = "top_center". So bar/attached/OSD slide from the top and notifications from the right — a panel sliding from the wrong edge is the single most common tell of a copy-pasted rice. The floating launcher is centred (shell.panel.launcher_position = "center"), where a slide has no natural origin, so `popin 90%` is correct there instead. `above_lock = true` on the OSD is the detail that makes volume keys usable on the lock screen — Noctalia's lockscreen uses ext-session-lock rather than layer-shell (there is deliberately no noctalia-lockscreen namespace), so without this the OSD is hidden behind it. `no_anim` on wallpaper/backdrop/click-shield prevents Hyprland double-animating surfaces that either never re-map or are invisible by design. IMPORTANT on blur: I initially planned `blur = true` here, but Noctalia v5 requests blur itself via the ext-background-effect-v1 protocol (src/wayland/surface.cpp: `ext_background_effect_surface_v1_set_blur_region`) with a precisely tessellated rounded-rect region matching its own radius, and Hyprland 0.56.2 implements that protocol (src/protocols/BackgroundEffect.cpp). The protocol path is strictly better than a layerrule because the blur is shaped to the corners instead of squaring off at the surface bounds. So the blur rules below are commented out as a fallback only — the real fix is the opacity precondition in the next change.

**Verified against:** Namespaces from exact source lines: src/shell/bar/bar.cpp:2395 ("noctalia-bar-" + barConfig.name), src/shell/panel/panel_manager.cpp:878 and src/shell/panel/persistent_panel_host.cpp:220 ("noctalia-panel"), panel_manager.cpp:1123 ("noctalia-attached-panel"), src/shell/panel/panel_click_shield.cpp:163, src/shell/notification/notification_toast.cpp:2065, src/shell/osd/osd_overlay.cpp:494, src/shell/backdrop/backdrop.cpp:252, src/shell/wallpaper/wallpaper.cpp:1233, src/shell/switcher/window_switcher.cpp:1056, src/shell/overview/overview_launcher_capture.cpp:144, src/capture/screenshot_region_overlay.cpp:404, src/capture/annotation_overlay.cpp:540. Live `hyprctl layers` shows noctalia-bar-default at level 2 on all three outputs. HL.LayerRuleSpec fields (above_lock, animation, blur, blur_popups, dim_around, enabled, ignore_alpha, match, name, no_anim, no_screen_share, order, xray) from hl.meta.lua lines 555-568. NOCTALIA_BLUR_TRACE is a real env flag at src/wayland/surface.cpp:85.

**Risk:** MAJOR CORRECTION to the brief: `ignorezero` no longer exists in Hyprland 0.56.2. There is no `ignore_zero`/`ignorezero` string anywhere in the binary and no such field on HL.LayerRuleSpec — only `ignore_alpha` survives. Every layerrule recipe online that lists `ignorezero` is pre-0.5x. I chose ignore_alpha = 0.3 for the commented fallback because it must sit below the surface body alpha (0.55 for glass panels, ~0.70 for the bar) and above ~0.1 so the antialiased corner fringe does not get a blurred halo.

```nix
# NEW top-level key inside settings, sibling of `curve` / `animation`.
layer_rule = [
  { name = "nocta-bar";      match = { namespace = "^noctalia-bar-"; };            animation = "slide top"; }
  { name = "nocta-attached"; match = { namespace = "^noctalia-attached-panel$"; }; animation = "slide top"; }
  { name = "nocta-panel";    match = { namespace = "^noctalia-panel$"; };           animation = "popin 90%"; }
  { name = "nocta-notif";    match = { namespace = "^noctalia-notification$"; };    animation = "slide right"; }
  { name = "nocta-osd";      match = { namespace = "^noctalia-osd$"; };             animation = "slide top"; above_lock = true; }
  { name = "nocta-switcher"; match = { namespace = "^noctalia-window-switcher$"; }; animation = "popin 92%"; }

  # No animation on surfaces that never re-map or are invisible by design.
  { name = "nocta-bg";     match = { namespace = "^noctalia-(wallpaper|backdrop)$"; }; no_anim = true; }
  { name = "nocta-shield"; match = { namespace = "^noctalia-panel-click-shield$"; };  no_anim = true; }
  { name = "nocta-capture";
    match = { namespace = "^noctalia-(screenshot-region|annotate|overview-launcher)$"; };
    no_anim = true; }

  # FALLBACK ONLY — Noctalia already requests shaped blur over
  # ext-background-effect-v1. Enable these one at a time and only if
  # NOCTALIA_BLUR_TRACE=1 shows the protocol path failing.
  # { name = "nocta-bar-blur";   match = { namespace = "^noctalia-bar-"; };   blur = true; ignore_alpha = 0.3; }
  # { name = "nocta-panel-blur"; match = { namespace = "^noctalia-panel$"; }; blur = true; ignore_alpha = 0.3; }
];
```

### 10. (high) PRECONDITION: Noctalia chrome is fully opaque today, so every blur change above is invisible

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** This is the finding that unblocks the whole domain. `noctalia config export full` on the live shell reports `bar.default.background_opacity = 1.0` and `shell.panel.transparency_mode = "solid"`. An opaque surface has nothing behind it to blur, so size 6 / passes 3 / popups true and every layer rule are dead weight until this changes. `glass` is a real enum value — the schema at src/config/schema/config_schema.cpp:1314 binds transparency_mode to kPanelTransparencyModes, and src/config/config_types.cpp:204-214 gives the exact alphas: Solid 1.0, Soft 0.80, Glass 0.55. 0.55 is the right target because it is low enough that a 48px blur radius genuinely shows through and high enough that Noctalia clamps card opacity to keep text readable (documented in docs/user/configuration/shell.mdx:229). For the bar I recommend 0.72 rather than glass-matching 0.55: the bar sits over arbitrary window content all day, not just wallpaper, and below ~0.65 the workspace pills and the clock start competing with whatever is underneath. 0.72 over a 48px blur at brightness 0.85 is the point where the wallpaper's colour reads through but nothing behind it is legible. This overlaps the chrome-shape domain — flag it there rather than fighting over ownership, but nothing in compositor feel lands without it.

**Verified against:** Live `noctalia config export full`: bar.default.background_opacity = 1.0, shell.panel.transparency_mode = "solid". Enum values and their exact alphas from .direnv/flake-inputs/h7afgccf35jrz4q5iyajr2x6q84ma1kd-source/src/config/config_types.cpp lines 204-214 and example.toml line 60 (`solid | soft | glass`). Noctalia's blur request path: src/shell/bar/bar.cpp:3168-3199 (applyBarCompositorBlur -> tessellateShape -> setBlurRegion) and src/wayland/surface.cpp:652-721.

**Risk:** Noctalia's OSD and notification surfaces are hardcoded-ish at background_opacity 0.97, so they will stay near-opaque and gain little from blur — that is fine and arguably correct for transient alerts. Also note `shell.panel.launcher_placement = "centered"` in the current file is dead v4 syntax; the live shell logs `unknown value "centered"` at config.toml:70:22. The v5 spelling is `launcher_placement = "floating"` plus `launcher_position = "center"`. Not my domain but it is confirmed broken.

```nix
# programs.noctalia.settings
bar.default = {
  # ... existing position / margin_ends / start / center / end ...
  background_opacity = 0.72;  # was 1.0 — REQUIRED for compositor blur to be visible
};

shell.panel = {
  transparency_mode = "glass";  # solid | soft | glass; glass = 0.55 panel bg alpha
};
```

### 11. (high) Window rules: the repo's first set — dialogs, per-app opacity, idle inhibit, tearing

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Rule order matters: Hyprland is last-match-wins, and the Nix list preserves order, so the universal `class = ".*"` rules go first and specific overrides after. The first two are lifted verbatim from Hyprland's own shipped example (suppress-maximize and the XWayland empty-class drag fix) — both are pure hygiene the repo is currently missing. Opacity is done per-app rather than globally so it never compounds with stylix.opacity.terminal: ghostty gets an explicit `opacity = 1.0` with `opacity_override = true` so that even if a global opacity is added later, ghostty's own 0.8 stands alone instead of becoming 0.76. Note Hyprland 0.56 splits opacity into distinct rule keys (opacity, opacity_inactive, opacity_fullscreen, and the three *_override booleans) rather than the old space-separated string. `idle_inhibit = "fullscreen"` on `.*` is the one-liner that stops the screen locking during video and games — necessary because all three Noctalia idle behaviours are about to be turned on. Tearing: yes, enable `general.allow_tearing`. It is only a master switch; tearing engages only when a window is fullscreen, solitary, and carries `immediate`. On the 240Hz DP-3 a tear line exists for 4.17ms and moves every frame, so it is effectively invisible, while the saving is a full frame plus the compositor queue. The 60Hz side panels are unaffected because no `immediate` window will ever live there. `no_blur` on games and video is not cosmetic — blur behind an opaque fullscreen surface is wasted GPU work and it prevents the solitary state that direct scanout and tearing both require (`hyprctl monitors` currently reports `solitaryBlockedBy: windowed mode,missing candidate`). A fullscreen game draws no visible border, so the looping borderangle does not block solitary either.

**Verified against:** Every property name confirmed as an exact standalone string in /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/bin/.Hyprland-wrapped: float, size, center, move, opacity, opacity_inactive, opacity_fullscreen, opacity_override, opacity_inactive_override, opacity_fullscreen_override, idle_inhibit, immediate, no_blur, no_focus, no_anim, no_shadow, no_border, no_rounding, dim_around, suppress_event, render_unfocused, stay_focused, xray, tag, pin, tile, keep_aspect_ratio, min_size, max_size, no_max_size, border_size, rounding, rounding_power, active_border_color, inactive_border_color, allows_input, focus_on_activate, fullscreen_state, nearest_neighbor, scroll_mouse, no_screen_share, persistent_size, sync_fullscreen, no_follow_mouse, no_initial_focus, no_shortcuts_inhibit, group, content. Match keys: class, title, initial_class, initial_title, xwayland, float/floating, fullscreen, fullscreen_state, pinned, focus, workspace, content, tag. idle_inhibit values: none, always, focus, fullscreen, fullscreenoutput, maximize, activatefocus. Rule shape (`{ name, match = {...}, <prop> = ... }`) from Hyprland's shipped hyprland.lua; I ran the HM renderer over this snippet with `nix eval` and it emits valid `hl.window_rule({...})` calls. Live app-ids from `hyprctl clients`: com.mitchellh.ghostty, dev.zed.Zed, librewolf, Spotify.

**Risk:** I used `[.]` character classes instead of backslash escapes throughout — functionally identical in POSIX ERE and it avoids a Nix string-escaping footgun. UNVERIFIED: `content = "video"` — the strings "none" and "game" exist in the binary but "video" and "photo" do not appear at all, so content-type matching is likely restricted; I used class-based rules instead. Also `size = "820 620"` uses the string form, matching the shipped example's `move = "20 monitor_h-120"`. blueman's actual class starts with a literal dot on NixOS (`.blueman-manager-wrapped`) — verify with `hyprctl clients` while it is open before trusting that pattern.

```nix
# NEW top-level key inside settings. ORDER MATTERS — last match wins.
window_rule = [
  # -- universal hygiene (both from Hyprland's own shipped example) --
  { name = "suppress-maximize"; match = { class = ".*"; }; suppress_event = "maximize"; }
  { name = "idle-inhibit-fs";   match = { class = ".*"; }; idle_inhibit = "fullscreen"; }
  { name = "fix-xwayland-drags";
    match = { class = "^$"; title = "^$"; xwayland = true; float = true; fullscreen = false; pinned = false; };
    no_focus = true; }

  # -- dialogs: float, size, centre --
  { name = "float-audio";   match = { class = "^(org[.]pulseaudio[.]pavucontrol|pavucontrol)$"; };
    float = true; size = "820 620"; center = true; }
  { name = "float-bt";      match = { class = "^([.]?blueman-manager(-wrapped)?)$"; };
    float = true; size = "720 560"; center = true; }
  { name = "float-net";     match = { class = "^(nm-connection-editor)$"; };
    float = true; size = "720 560"; center = true; }
  { name = "float-portal";  match = { class = "^(xdg-desktop-portal-gtk)$"; };
    float = true; size = "1000 680"; center = true; }
  { name = "float-picker";  match = { title = "^(Open|Save|Select|Choose|Datei).*"; };
    float = true; size = "1000 680"; center = true; }
  { name = "polkit-modal";
    match = { class = "^(hyprpolkitagent|polkit-gnome-authentication-agent-1)$"; };
    float = true; center = true; dim_around = true; }

  # -- per-app opacity (never global; see the opacity change) --
  { name = "opaque-term";   match = { class = "^(com[.]mitchellh[.]ghostty)$"; };
    opacity = 1.0; opacity_override = true; }
  { name = "glass-files";   match = { class = "^(org[.]gnome[.]Nautilus|thunar)$"; };
    opacity = 0.94; opacity_inactive = 0.90; }
  { name = "opaque-media";  match = { class = "^(mpv|vlc|Spotify)$"; };
    opacity = 1.0; opacity_override = true; no_blur = true; }

  # -- games on the 240 Hz DP-3 --
  { name = "game-immediate"; match = { class = "^(steam_app_.*|gamescope)$"; };
    immediate = true; no_blur = true; render_unfocused = true; }
];
```

### 12. (medium) misc / render / NVIDIA: tearing, direct scanout, and two options that no longer exist

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Two corrections first, both verified. `misc.vfr` DOES NOT EXIST in Hyprland 0.56.2 — `hyprctl getoption misc:vfr` returns 'no such option' and the ConfigKey list jumps straight from misc.swallow_regex to misc.vrr. VFR is unconditional now; anyone recommending `misc { vfr = true }` is quoting a pre-0.5x wiki. `render.explicit_sync` and `render.explicit_sync_kms` also DO NOT EXIST — there is no key containing 'explicit' anywhere in the 0.56 render namespace. Explicit sync is mandatory and always on, which retires the single most-cited NVIDIA Hyprland tweak. On the ones that do exist: `render.direct_scanout` is currently 0, which is exactly the 'directScanoutBlockedBy: user settings' in the brief — setting it to 1 lets a fullscreen solitary client bypass compositing entirely, which together with `immediate` on games is where the real latency win on DP-3 comes from. `render.ctm_animation` is at 2 (auto); on the NVIDIA proprietary driver the animated colour-transform-matrix path is the known cause of session hangs when a nightlight toggles, and Noctalia's control centre has exactly that shortcut wired up — setting 0 takes the animation off that path. `misc.render_unfocused_fps` 30 (from 15) pairs with the `render_unfocused` game rule: 15fps is enough to keep a game's timers alive but visibly stutters if you glance at it on another monitor, and on a 5760px canvas you often can. `misc.background_color` must be set explicitly because Stylix currently owns it and is about to be switched off — without it you get Hyprland's default blue flash before the wallpaper daemon paints. On VRR: leave `misc.vrr = 0` and do NOT set per-monitor vrr on DP-3. The Acer XB252Q is a hardware G-SYNC module panel, `hyprctl monitors` reports `vrr: false` for it, and its availableModes list shows only fixed modes — G-SYNC module panels do not expose DisplayPort Adaptive-Sync the way the Wayland VRR path expects. `cursor.no_hardware_cursors` is at 2 (auto) and should stay: forcing software cursors would cost a full-screen damage rect on every cursor move across 5760px.

**Verified against:** `hyprctl getoption misc:vfr` -> 'no such option' on the running 0.56.2. Full misc.* and render.* key lists read from hl.meta.lua lines 319-358 and 362-378 — no vfr, no explicit_sync. Live values via `hyprctl getoption`: general:allow_tearing false, misc:vrr 0, misc:render_unfocused_fps 15, render:direct_scanout 0, render:ctm_animation 2, render:new_render_scheduling false, cursor:no_hardware_cursors 2. `hyprctl monitors` for DP-3: vrr false, solitary 0, solitaryBlockedBy 'windowed mode,missing candidate', currentFormat XRGB8888, availableModes 1920x1080@240/200/144/120/100/60 (no adaptive-sync range).

**Risk:** The integer semantics of render.direct_scanout (0 off / 1 on / 2 content-type-gated) and render.ctm_animation are INFERRED from the stub's `integer|boolean` typing and Hyprland convention — I could not find enum documentation in the binary. Both are cheap to revert live with `hyprctl keyword`. Do NOT enable render.new_render_scheduling; it is currently false and is explicitly experimental. Given deadPc is a nix-mineral host, apply this with `nixos-rebuild boot` + reboot as CLAUDE.md advises so the prior generation stays bootable.

```nix
# inside settings.config.general
allow_tearing = true;   # master switch only; per-window `immediate` does the work

# inside settings.config.misc (add to the existing block)
background_color    = "rgb(11111b)"; # Stylix owned this; it is about to be disabled
render_unfocused_fps = 30;           # was 15; pairs with the game render_unfocused rule

# NEW block inside settings.config
render = {
  direct_scanout = 1;  # was 0 — this is the 'directScanoutBlockedBy: user settings'
  ctm_animation  = 0;  # NVIDIA proprietary: keep nightlight off the animated CTM path
};

# DO NOT ADD, verified absent in 0.56.2:
#   misc.vfr             -> 'no such option'; VFR is unconditional now
#   render.explicit_sync -> removed; explicit sync is mandatory
#   monitor vrr on DP-3  -> XB252Q is a G-SYNC module panel, reports vrr: false
```

### 13. (high) Demote the Stylix Hyprland target (frees the colours AND kills the stray hyprpaper layer)

**File:** `modules/home-manager/core/stylix.nix`

**Rationale:** One line fixes two problems. Stylix's hyprland target currently writes decoration.shadow.color, general.col.active_border, general.col.inactive_border, the whole group/groupbar colour set, and misc.background_color into settings.config — all of which Noctalia is about to own, and all of which would fight the gradient. The same target also auto-enables hyprpaper because stylix.image is non-null, which is why `hyprctl layers` shows a hyprpaper surface painting a background layer under noctalia-wallpaper on all three monitors right now (pid 4473 vs 4475). Disabling the whole target is strictly better than the narrower `stylix.targets.hyprland.hyprpaper.enable = false` in the brief, because mkTarget wraps the target's entire config in `lib.mkIf (config.stylix.enable && cfg.enable)` — so one switch removes both the duplicate wallpaper daemon and the colour conflict. Nothing else in the repo references hyprpaper (grepped), so there is no other source keeping it alive. This is why the previous changes set misc.background_color and shadow.color explicitly: once this flips, nobody else is setting them.

**Verified against:** .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/hyprland/hm.nix — reads in full: it sets decoration.shadow.color, general.col.active_border/inactive_border, the group + groupbar colour block and misc.background_color, and in a second block sets services.hyprpaper.enable = true guarded on `image != null`. Gating confirmed at .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/stylix/mk-target.nix:326 (`config = lib.mkIf (config.stylix.enable && cfg.enable) (...)`). Live evidence of the duplicate layer: `hyprctl layers` shows namespace hyprpaper AND namespace noctalia-wallpaper both at level 0 on HDMI-A-1, DP-2 and DP-3. `grep -rn hyprpaper` over the repo (excluding .direnv) returns nothing.

**Risk:** modules/nixos/desktop/stylix.nix is a hand-synced duplicate of this file; it does not carry a hyprland target block today, but check it before assuming the change is complete. Also note the same demotion needs to happen for stylix.opacity.terminal if Noctalia's ghostty template is enabled, or the two will disagree about terminal alpha — that is the colour-authority agent's call, not this one's.

```nix
# stylix.targets
targets = {
  hyprlock.enable = false;
  starship.enable = false;
  # Noctalia owns Hyprland's colours via its `hyprland` template. Disabling this
  # target also stops Stylix auto-enabling hyprpaper, which was painting a dead
  # background layer underneath Noctalia's wallpaper on all three monitors.
  hyprland.enable = false;
  librewolf.profileNames = [ "Default" ];
};
```

### 14. (low) Remove ghostty's background-blur — it is a no-op under Hyprland

**File:** `modules/home-manager/terminal/ghostty.nix`

**Rationale:** `background-blur = 10` does nothing on this system and is a false lead that will send someone chasing the wrong knob. Ghostty implements Linux background blur exclusively over the KDE blur protocol — its binary contains KWin-specific help text ('Blur plugin. If disabled, enable it by ticking the checkbox to the left') and the runtime error 'winproto_wayland: failed to sync blur'. Hyprland 0.56.2 does not implement org_kde_kwin_blur at all (no such string in the binary); what it does implement is ext-background-effect-v1, which ghostty does not use. The blur behind ghostty comes entirely from Hyprland's own decoration:blur acting on the window's 0.8 alpha, which the blur change above is what actually tunes. Leave background-opacity alone — that is Stylix's stylix.opacity.terminal = 0.8 flowing through, and it is the thing making the blur visible in the first place.

**Verified against:** `strings` over /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/bin/.Hyprland-wrapped: no match for kde_kwin_blur / kwin_blur / blur_manager; the only blur protocol present is ext_background_effect_manager_v1 (src/protocols/BackgroundEffect.cpp). `strings` over /nix/store/444h3sfs9fk7fi8hif6wgg11rkc24vjd-ghostty-1.3.1/bin/ghostty: 'winproto_wayland: failed to sync blur' and the KWin 'Blur plugin' checkbox help text. Live ~/.config/ghostty/config confirms background-blur = 10 and background-opacity = 0.800000.

**Risk:** None. Cosmetic cleanup only — removing it changes no rendered pixel.

```nix
settings = {
  command = "tmux new-session -A -s main";
  term = "xterm-256color";
  font-size = 11;

  # background-blur removed: ghostty implements Wayland blur only over the KDE
  # blur protocol, which Hyprland does not implement. The blur behind this
  # window comes from Hyprland's decoration:blur acting on the 0.8 alpha that
  # stylix.opacity.terminal sets.

  window-new-tab-position = "end";
  # ... keybind list unchanged ...
};
```

## Open questions

SYNTAX — RESOLVED WITH CERTAINTY, no ambiguity to flag. `settings.curve`, `settings.animation`, `settings.window_rule` and `settings.layer_rule` are all correct declarative Nix; the HM renderer at .direnv/flake-inputs/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules/services/window-managers/hyprland.nix:531-580 turns each into `hl.<name>(...)`, expands `_args` into a multi-argument call, and emits one call per list element. `importantPrefixes` already contains "curve", so curves are emitted before animations without intervention. `animations.bezier` as a config key does not exist in 0.56 (the ConfigKey alias list has only animations.enabled and animations.workspace_wraparound), so the old hyprlang list form CANNOT work and hl.curve() is mandatory. I confirmed the exact generated Lua by running the renderer's own logic over my snippets with `nix eval`.

GENUINELY UNCERTAIN, flagged rather than asserted:
1. Auto-reload on palette change. I found `safeLuaRequire` and the log string `[lua] file {} modified, reloading` in the Hyprland binary, which strongly implies required Lua files are watched and a Noctalia palette rewrite triggers a config reload. I did NOT observe this happen live. If it does not fire, add a Noctalia user template whose post_hook runs `hyprctl reload`.
2. Whether `speed` is honoured or ignored when a `spring` curve is given. Hyprland's own default preset supplies both for `windows`, so supplying both is safe, but do not expect the number to be the knob.
3. Bezier control points with y > 1 (the `overshot` curve). Overshoot beziers are widely used in Hyprland configs and Hyprutils' evaluator is generic, but I could not prove Hyprland does not clamp. Fallback: `spring = "bouncy"` on windowsIn.
4. The integer semantics of `render.direct_scanout` and `render.ctm_animation`. Both keys exist and are typed integer|boolean, but I found no enum documentation; 0/1/2 = off/on/auto is convention, not verified.
5. Whether adding a `blur = true` layerrule on top of Noctalia's ext-background-effect-v1 blur region composes or double-blurs. I read both sides' source but did not test. That is why the blur layerrules are commented out with `NOCTALIA_BLUR_TRACE=1` named as the diagnostic.
6. `content = "video"` as a window-rule match. "none" and "game" exist as standalone strings in the binary; "video" and "photo" do not appear at all, so I avoided content matching entirely.
7. blueman's exact app-id on this system (I believe `.blueman-manager-wrapped` with a leading dot, the usual NixOS wrapper artefact) — verify with `hyprctl clients` while it is open.

CROSS-DOMAIN DEPENDENCIES the orchestrator needs to resolve:
- The Noctalia opacity precondition (bar.default.background_opacity, shell.panel.transparency_mode) sits in chrome-shape's file but gates every blur change here. It must not be dropped.
- Enabling the `hyprland` builtin template belongs to colour-authority, but the gradient border here is inert without it, and its post_hook will fail noisily every render under Home Manager.
- Disabling stylix.targets.hyprland transfers ownership of misc.background_color and decoration.shadow.color to this domain, which is why both are set explicitly above.

DELIBERATELY NOT PROPOSED, per the out-of-scope list: rounded screen corners (Noctalia's `noctalia-screen-corner` layer), desktop widgets, dock, hot corners. `decoration.glow.*` and `decoration.motion_blur.*` are new and real in 0.56.2 but I left both off — glow duplicates what the animated gradient border already says, and motion_blur on a mixed 60/240Hz setup samples inconsistently across monitors.
