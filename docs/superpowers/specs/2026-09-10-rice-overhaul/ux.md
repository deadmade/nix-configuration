# Interaction

_INTERACTION — keybindings, daemons, idle/polkit, and the finishing layer_

The interaction layer has one live bug that dwarfs everything else: Hyprland resolves a single-character bind key with BOTH `xkb_keysym_from_name(key, NO_FLAGS)` and `(key, CASE_INSENSITIVE)` and then executes *every* matching bind (it builds a `bindsHit` vector, it does not stop at the first hit), so `SUPER+l` currently fires focus-right **and** locks the screen, `SUPER+SHIFT+l` fires move-window-right **and** lock-and-suspend, and `SUPER+J` fires focus-down **and** togglesplit. That must be fixed before any new binds are layered on. Beyond it, the design is a four-modifier grammar — SUPER = focus/launch, SUPER+SHIFT = move/alternate, SUPER+CTRL = resize, SUPER+ALT = monitor — with every non-window action routed through `noctalia msg` so the OSD (15 kinds enabled, currently fed by nothing) finally has something to show. `SUPER+E` is fixed to yazi-in-ghostty with Nautilus on SHIFT+E, `hyprshot` and `wofi-emoji` are replaced by the Noctalia subsystems that already duplicate them, Noctalia's own polkit agent (compiled in, linked against libpolkit-agent-1 + PAM — verified with `ldd`) is switched on, and the idle ladder goes from "never locks" to a 15/20-minute desktop ladder and a 5/6/15-minute laptop ladder with a 5-second fade as the warning. On the daemon side deadPc gets `upower` + `power-profiles-daemon` (both tiny, both fix logged failures), and brightness keys become real on a backlight-less desktop via `ddcutil` over the eight `/dev/i2c-*` buses that already exist but are root-only.

## Fatal problems flagged by the verifier

Four things will break a build or a session if this design is implemented as literally written.

1. BUILD BREAK — hosts/deadPc/config.nix (ddcutil change). The snippet adds `environment.systemPackages = [pkgs.ddcutil];` and `users.users.deadmade.extraGroups = ["networkmanager" "wheel" "i2c"];` as new top-level attributes, but that file already defines `users.users.deadmade = { … extraGroups = [...]; }` at line 78-86 and `environment.systemPackages = with pkgs; [...]` at line 94. Nix merges attr-path PREFIXES but errors on a duplicated LEAF — proven: `nix eval --impure --expr '{ e.p = [1]; e.p = [2]; }'` → `error: attribute 'e.p' already defined`. Both lines must be edited in place. (`hardware.i2c.enable = true;` is fine as a new top-level attr despite the existing `hardware = { … }` block at line 117.)

2. BUILD BREAK — modules/home-manager/windowManager/hyprland/noctalia.nix. The design hands over FOUR separate snippets that each open `shell = { … };` (window_switcher, polkit_agent, screenshot, panel/launcher_placement) plus a second `bar = { … };` for the dead zone. The file already has a `shell = { avatar_path; panel.launcher_placement; }` block and a `bar = { order; default = {...}; }` block. Pasting them side by side is `error: attribute 'shell' already defined` / `'bar' already defined`. All of it has to be folded into ONE `shell` block and ONE `bar` block. Same for `terminal._var` in config.nix, which the SUPER+E change re-declares at a line that already exists (config.nix:8).

3. SESSION BREAK — additive keybinds. The design correctly proves that Hyprland executes EVERY matching bind (bindsHit, no first-match-wins), then presents almost every new bind as an addition while the identical old bind stays in the file. It names only three lines for removal (J, L, SHIFT+L). Left as is: SUPER+SPACE runs `panel-toggle launcher` twice and the launcher opens then instantly closes; same for SUPER+X, SUPER+N, SUPER+SHIFT+S; and every SUPER+SHIFT+<direction> moves the window two slots because the `dirs` loop duplicates the 16 existing focus/move binds. This change must be framed as a rewrite of the keybinding section of extraConfig, with an explicit deletion list.

4. FUNCTIONAL BREAK — the recorder toggle. `sh -c "pkill -SIGINT -f gpu-screen-recorder || gpu-screen-recorder …"` makes `pkill -f` match its own parent shell's cmdline, SIGINT it, exit 0, and never reach the `||` branch. Recording never starts. Fix is `pkill -SIGINT -x gpu-screen-recorder`.

One reasoning error worth correcting even though it does not break anything: the design twice tells the user that list-valued Noctalia settings "collide" across modules and that this is why `behavior_order` must live in one place. They do not collide — I proved with `lib.types.toml.merge` that attrsets merge recursively and lists CONCATENATE SILENTLY. The advice is right; there is no error to catch a mistake, so use `lib.mkForce` if you want a guard.

Everything genuinely load-bearing that I could check held up: the case-insensitive keysym double-dispatch is real and reproduced verbatim from v0.56.2 source plus live `hyprctl binds`; every Noctalia option name, enum value and IPC verb used in the design exists in the v5 schema or `noctalia msg --help`; every Hyprland dispatcher, bind flag and window-rule property exists in the stubs, the shipped example config, the wiki, or the binary's string table; and all five new packages/options (hyprpicker, ddcutil, yazi, gpu-screen-recorder, hardware.i2c/upower/power-profiles-daemon/programs.gpu-screen-recorder) resolve on this flake. Two settings in the compositor block (`extend_border_grab_area = 15`, `hover_icon_on_border = true`) are already the live defaults and change nothing.

## Verdicts

### [CONFIRMED] CRITICAL: SUPER+L / SUPER+J each fire two dispatchers (case-insensitive keysym collision)

**Evidence:** WebFetch of https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/src/managers/KeybindManager.cpp returns verbatim `const auto KBKEY = xkb_keysym_from_name(k->key.c_str(), XKB_KEYSYM_NO_FLAGS); const auto KBKEYLOWER = xkb_keysym_from_name(k->key.c_str(), XKB_KEYSYM_CASE_INSENSITIVE);` then `if (key.keysym != KBKEY && key.keysym != KBKEYLOWER) continue;`, and the collection loop does `bindsHit.emplace_back(k);` with `break` ONLY for `k->handler == "submap"`, followed by `for (const auto& k : bindsHit) { ... }`. Live `hyprctl binds` (51 binds) shows exactly the entries the design names: #6 modmask 64 key J, #14 modmask 64 key L, #15 modmask 65 key L, #21 modmask 64 key j, #23 modmask 64 key l, #49 modmask 65 key j, #51 modmask 65 key l. `hyprctl getoption input:resolve_binds_by_sym` = `bool: false set: false`, so name resolution (not sym) is in play. Source lines are modules/home-manager/windowManager/hyprland/config.nix — the three offending binds are `+ J` togglesplit, `+ L` lock, `+ SHIFT + L` lock-and-suspend.

**Correction:**

Substance is right; only the cited line numbers are wrong for v0.56.2 — the dual keysym resolve is at ~1031-1045 and the bindsHit execution loop at ~1082-1150, not 702-726/773-836. `hl.dsp.layout("togglesplit")` is legal (dispatchers.md: `layout( message )` takes a string). `escape`/`return` as bind key names resolve via XKB_KEYSYM_CASE_INSENSITIVE, which is exactly what the wiki's own submap example relies on (`hl.bind("escape", hl.dsp.submap("reset"))`), so SUPER+escape is safe.

### [CONFIRMED] Media / volume / mic / brightness keys via noctalia msg

**Evidence:** `noctalia msg --help` lists volume-up/down [step], volume-mute, mic-mute, `media <action>`, brightness-up/down [target] [step], and screenshot-*. docs/user/ipc/system-controls.mdx:55-63 gives `brightness-down * 5%` verbatim and states targets are `current|all|*|<connector>` with values `0.0-1.0` or `65|65%|5%`. Flag names verified in the wiki flags.md table (`locked`, `repeating`, `description`) and in the shipped /nix/store/79107j…-hyprland-0.56.2/share/hypr/hyprland.lua:294-305 which uses the same XF86 spellings with `{ locked = true, repeating = true }`. `media toggle/next/previous/stop/pause` all in docs/user/ipc/media-and-ui.mdx:65-72.

### [WRONG] Noctalia surfaces keymap (SUPER+A control-center, SUPER+N notifications tab, /emo, screenshots)

**Evidence:** Option names all check out: src/app/application_ui.cpp:571,573,574,635,700,706,707,710 register exactly clipboard/session/test/launcher/control-center/tray-drawer/polkit/setup-wizard — no `notifications` panel, so the current `panel-toggle notifications` is dead. `notifications` IS a valid control-center context (docs/user/control-center/index.mdx tab table; src/shell/control_center/control_center_panel.h:135 `{TabId::Notifications, "notifications", ...}`). `/emo` confirmed (shell.mdx:107 provider_prefix "/", :114-115 emoji prefix "emo"). window-switcher, settings-toggle, notification-dnd-toggle, caffeine-toggle, screenshot-region/-fullscreen/-annotate all in `noctalia msg --help`. WHAT IS WRONG is the delivery: the snippet adds SUPER+SPACE, SUPER+X, SUPER+N and SUPER+SHIFT+S while config.nix already binds all four, and per finding #1 Hyprland runs EVERY match — two `panel-toggle launcher` binds on SUPER+SPACE open then immediately close it. The design only marks J/L/SHIFT+L for removal.

**Correction:**

State explicitly that these existing lines must be DELETED, not shadowed: `hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))`, `hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("wofi-emoji"))`, `hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle notifications"))`, `hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region output --clipboard-only"))`, `hl.bind(mainMod .. " + F", ...)`, `hl.bind(mainMod .. " + Q/W/E", ...)`. Safest framing: this change rewrites the whole keybinding section of extraConfig rather than appending to it.

### [CONFIRMED] shell.window_switcher.mru = true

**Evidence:** example.toml:110-111 `[shell.window_switcher]` / `mru = false  # order windows by most recently used (Alt+Tab) instead of workspace layout`; docs/user/configuration/shell.mdx:164; and `noctalia config export full` lines 592-593 show `[shell.window_switcher] mru = false` in the live schema.

**Correction:**

Note that docs/user/ipc/shell.mdx:29 and shell.mdx:265 both claim "There is no `[shell.window_switcher]` configuration block yet" — stale prose contradicting the schema. Schema wins. Separate risk the design misses: ipc/shell.mdx:41 says the overlay "takes exclusive keyboard focus on its layer surface", but Hyprland processes binds before forwarding, so a second ALT+Tab while the overlay is open may re-invoke the IPC verb (`--help` calls it "Open or close") and close it. Hold-Alt-tap-Tab-repeatedly may not work; verify after rebuild.

### [WRONG] Window management: mouse drag/resize, directional grammar, fullscreen variants, groups

**Evidence:** Every API name checks out. `{ mouse = true }` is real despite being absent from the HL.BindOptions stub class (hl.meta.lua:437-453) — the shipped hyprland.lua:290-291 has `hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })` and wiki binds/flags.md lists `mouse` in the flag table. dispatchers.md confirms `focus({ direction })`, `focus({ monitor })`, `focus({ last })`, `window.move({ direction })`, `window.move({ monitor, follow? })`, `window.resize({ x, y, relative? })`, `fullscreen({ mode })` with mode "maximized"/"fullscreen", `fullscreen_state({ internal, client })` with the verbatim note "`{internal = 2, client = 0}` fullscreens the application but pretends to the client that it is still in non-fullscreen mode", and group.toggle/next/prev/lock_active. naming-conventions.md:198-212 confirms monitor selectors take direction `l`/`r`/`u`/`d`. hyprsplit's `hs.dsp.focus` does handle `"e+1"` (~/.config/hypr/hyprsplit/init.lua:142-174). SAME DEFECT AS #3: the `dirs` loop re-registers all 16 focus/move binds that config.nix lines already define, and both fire — SUPER+SHIFT+left would move the window two slots, not one.

**Correction:**

Delete the existing 16 focus/move bind lines from config.nix before adding the loop. `hl.dsp.focus({ last = true })` remains UNVERIFIED — the wiki writes the param bare as `focus({ last })` and I found no example with a value; keep the design's own advice to drop that one line if it misbehaves. Note the wiki's own resize example inverts the design's y convention (`up` → `y = 10`), so the design's up=-40/down=+40 is a deliberate choice, not the wiki's.

### [CONFIRMED] Resize submap on SUPER+R

**Evidence:** wiki binds/submaps.md gives the exact shape: `hl.bind("ALT + R", hl.dsp.submap("resize"))` / `hl.define_submap("resize", function() hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true}), { repeating = true }) ... hl.bind("escape", hl.dsp.submap("reset")) end)`. hl.meta.lua:826 `define_submap fun(name: string, reset_or_fn: string|function, fn?: function): nil`. Escape-hatch `hyprctl dispatch 'hl.dsp.submap("reset")'` is documented verbatim in submaps.md.

**Correction:**

Ordering constraint the snippet does not state: `local dirs = {...}` from the previous change must appear ABOVE `hl.define_submap` in the same extraConfig string, or `dirs` is nil at closure-call time. The catchall rationale (KeybindManager `found` gating) I could not verify against v0.56.2 source — mark it uncertain; the decision not to add a catchall is safe regardless.

### [CONFIRMED] Scratchpad on SUPER+minus / SUPER+SHIFT+minus

**Evidence:** dispatchers.md §Special workspaces gives verbatim `hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))` and `hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))`, plus the note "Dispatchers that only handle special workspaces … accept a name and apply the `special:` prefix themselves." `minus` and `comma` are unshifted keys on the de layout (`hyprctl getoption input:kb_layout` is set to "de" in config.nix:16). Neither key is bound anywhere in the current config.

### [CONFIRMED] Window rules: idle-inhibit + float the Noctalia settings window

**Evidence:** wiki rules/window-rules.md:116 `| idle_inhibit | Sets an idle inhibit rule. Modes: "none", "always", "focus", "fullscreen" | str |` (dynamic effects table); :68 `center`, :70 `float`, :82 `size` (static effects); :28 `class` match key. `strings` on /nix/store/79107j…-hyprland-0.56.2/bin/.Hyprland-wrapped has exact-match hits for idle_inhibit, center, size, float, initial_class. The shipped hyprland.lua:326-340 confirms the `hl.window_rule({ name, match = {...}, <prop> })` shape. Noctalia's own docs/user/compositor-settings/hyprland.mdx:88-93 ships `hl.window_rule({ match = { class = "dev.noctalia.Noctalia" }, float = true, size = { 1080, 920 } })`, and the app id is confirmed by /nix/store/qiipyv…-noctalia-5.0.1/share/applications/dev.noctalia.Noctalia.desktop. docs/user/services/idle.mdx:65 "Idle behavior uses the Wayland `ext_idle_notifier_v1` protocol and respects active idle inhibitors." The Nix `''…''` escaping analysis is correct: `\` is not an escape in an indented Nix string, so `\\.` reaches Lua as `\\.` and Lua yields `\.`.

### [WRONG] Compositor settings: resize_on_border, extend_border_grab_area, hover_icon_on_border, snap, scroll_event_delay, workspace_back_and_forth

**Evidence:** Live `hyprctl getoption`: `binds:scroll_event_delay` int: 300 set: false; `binds:workspace_back_and_forth` bool: false; `general:resize_on_border` bool: false; `general:snap:enabled` bool: false — those four are genuine changes. BUT `general:extend_border_grab_area` is already `int: 15 set: false` and `general:hover_icon_on_border` is already `bool: true set: false`. Two of the six lines change nothing. hyprsplit integration confirmed: ~/.config/hypr/hyprsplit/init.lua:221-235 reads `hl.get_config("binds.workspace_back_and_forth")` and routes to `previous_per_monitor`.

**Correction:**

Drop `extend_border_grab_area = 15;` and `hover_icon_on_border = true;` — both are already the defaults, so they add config noise for zero effect (or raise the grab area above 15 if that is the actual intent). Also: the snippet reprints the whole `general` block including layout/gaps_in/gaps_out/border_size, which already exists at config.nix:26-31 — it must be edited in place; pasting it as a second `general = { … }` inside the same `config = { … }` literal is `error: attribute 'general' already defined`.

### [WRONG] Fix SUPER+E: thunar not installed — yazi in ghostty, Nautilus on SHIFT+E

**Evidence:** `command -v thunar` is empty; the only repo hit for thunar is config.nix:9 `fileManager._var = "thunar"`. `nix eval` on the flake: nautilus-50.2.2 and yazi-26.5.6 both resolve; services.tumbler.enable evaluates false and services.gvfs.enable true, so the Thunar/Nemo/Dolphin reasoning holds. `ghostty --help` confirms "A special command line argument `-e <command>` can be used to run the specific command inside the terminal emulator." flake/modules/constants.nix:12-13 does say browser="helium", terminal="kitty" — the staleness claim is right. WHAT IS WRONG: `terminal._var = "ghostty";` and `fileManager._var = …` already exist at config.nix:8-9. Re-declaring the same leaf in the same attrset is `error: attribute 'terminal' already defined` (verified: `nix eval --expr '{ a = { b = 1; }; a.b = 2; }'` → "attribute 'a.b' already defined").

**Correction:**

Edit config.nix:8-9 in place and add only the new local:
      terminal._var = "ghostty";
      browser._var = "librewolf";
      fileManager._var = "ghostty -e yazi";
and delete the two hardcoded `"librewolf"` strings in extraConfig (the `hl.on("hyprland.start", …)` autostart and the SUPER+W bind) rather than adding new binds beside them.

### [CONFIRMED] New module: modules/home-manager/terminal/yazi.nix

**Evidence:** flake/lib/registry.nix auto-discovers `foo.nix` as attr `foo` in the domain registry; profiles/home-manager/desktop-dev.nix does `++ (builtins.attrValues outputs.homeManagerModules.terminal)`, and both deadPc (via desktopGaming → desktopDev) and deadConvertible import it. The pinned home-manager (.direnv/flake-inputs/v573js…-source/modules/programs/yazi.nix:68 `options.programs.yazi`, :118 `enableZshIntegration = lib.hm.shell.mkZshIntegrationOption { inherit config; }`) has both options. `nix eval` → yazi-26.5.6.

**Correction:**

The stylix conflict is real and worse than a footnote: /nix/store/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/yazi/hm.nix sets `programs.yazi.theme` unconditionally once the target is enabled, so the moment `programs.yazi.enable = true` lands, Stylix owns yazi's colours — directly against decision #1. Add `stylix.targets.yazi.enable = false;` in the same file if colour authority is Noctalia.

### [CONFIRMED] Package set: drop hyprshot and wofi-emoji, add hyprpicker

**Evidence:** modules/home-manager/windowManager/hyprland/default.nix:18-23 currently lists hyprshot, networkmanagerapplet, wofi-emoji. `nix eval .#nixosConfigurations.deadPc.pkgs.hyprpicker.name` → hyprpicker-0.4.7. Noctalia's screenshot subsystem is real (`screenshot-region`, `screenshot-fullscreen [mode]`, `screenshot-annotate` in `noctalia msg --help`; `[shell.screenshot]` block in docs/user/configuration/shell.mdx:179-186).

### [CONFIRMED] Turn on Noctalia's polkit agent (shell.polkit_agent = true)

**Evidence:** `ldd /nix/store/qiipyv1s07rp6myhbla2bh5rgg0g61lf-noctalia-5.0.1/bin/.noctalia-wrapped` → libpolkit-agent-1.so.0, libpolkit-gobject-1.so.0, libpam.so.0 (all resolved to polkit-127 / linux-pam-1.7.2). application_ui.cpp:707 `registerPanel("polkit", std::make_unique<PolkitPanel>(...))`. docs/user/configuration/shell.mdx:198: "`polkit_agent` controls registration on `org.freedesktop.PolicyKit1` … defaults `polkit_placement = \"floating\"` with `polkit_position = \"center\"`", and :234 confirms placement accepts only attached|floating. `nix eval` on deadPc: security.polkit.enable = true, security.pam.services.login.enableGnomeKeyring = true, security.pam.services.greetd.enableGnomeKeyring = true. Noctalia's authenticator does hardcode the PAM service: src/auth/pam_authenticator.h:13 `service = "login"`, pam_authenticator.cpp:184 and :242.

**Correction:**

The two placement/position lines are already the documented defaults, so they are documentation-only. See the fatal note about four separate `shell = { … }` snippets.

### [CONFIRMED] Idle ladder: deadPc — 15 min lock / 20 min screen-off / no suspend

**Evidence:** `noctalia config export full` lines 197-224 show `[idle] behavior_order = [ "lock", "screen-off", "lock-and-suspend" ]`, `pre_action_fade_seconds = 2.0`, and all three behaviors `enabled = false` — the "never locks" claim is real. docs/user/services/idle.mdx:14-20 documents `behavior_order = ["lock", "screen-off", "suspend"]` verbatim and `pre_action_fade_seconds` "Parsed between 0 and 120". Actions lock/screen_off/suspend/lock_and_suspend/command confirmed in the settings table. `locked_timeout` is real: src/config/schema/config_schema.cpp:907 `field(&IdleBehaviorConfig::lockedTimeoutSeconds, "locked_timeout")`, idle_manager.h:45 "While locked, behaviors with a positive lockedTimeoutSeconds re-arm at that shorter timeout", idle_manager.cpp:95-96. `[lockscreen] fingerprint = true` and `lock_before_suspend = true` are both in the live export. Renaming the third behavior from the seeded `lock-and-suspend` to `suspend` is legal — idle.mdx:8 says behaviors are arbitrary named entries and seeding happens only "When the resolved config does not define idle behaviors". Hyphenated Nix attr names verified: `nix eval --expr '{ screen-off = { a = 1; }; }'` evaluates fine.

### [WRONG] Idle ladder: deadConvertible host override merges into the shared block

**Evidence:** The merge claim is TRUE and I proved it: `lib.types.toml.merge ["x"] [{value={idle={behavior_order=["lock"]; behavior.lock.timeout=900;};};} {value={idle={behavior_order=["screen-off"]; behavior.lock.enabled=true;};};}]` → `{ idle = { behavior = { lock = { enabled = true; timeout = 900; }; }; behavior_order = [ "lock" "screen-off" ]; }; }` (lib/types.nix:1451-1471 serializableValueWith; nix/home-module.nix:47-53 `oneOf [tomlFormat.type str path]`). But the stated failure mode for lists is WRONG: lists do not collide, they CONCATENATE SILENTLY. A `behavior_order` or `osd.monitors` defined in both the shared module and a host produces a silently-merged nonsense list, not an eval error.

**Correction:**

Keep the advice (define each list exactly once) but fix the reasoning: there is no loud error to catch a mistake here. If you want the guard, write the list with `lib.mkForce` in the shared module so a host redefinition is a visible conflict instead of a silent append.

### [CONFIRMED] deadPc daemons: services.upower + services.power-profiles-daemon

**Evidence:** `nix eval` on deadPc: services.upower.enable = false, services.power-profiles-daemon.enable = false, services.tlp.enable = false (no conflict), hardware.logitech.wireless.enable = true. Both options exist on this host. ppd will actually have profiles to expose: /sys/devices/system/cpu/amd_pstate/status = `active` and cpu0 scaling_driver = `amd-pstate-epp`. docs/user/ipc/system-controls.mdx notes the power-profile verbs need org.freedesktop.UPower.PowerProfiles; docs/user/control-center/index.mdx says the `power` tab "opens only when UPower or `power-profiles-daemon` is available".

### [WRONG] deadPc brightness: hardware.i2c + ddcutil + i2c group + [brightness] settings

**Evidence:** Live facts all check out: `ls /sys/class/backlight/` is empty; /dev/i2c-0..7 exist; `getent group i2c` → rc=2 (no group); nix-mineral compatibility.nix:75 `kernel-modules.enable = false`. `nix eval` confirms hardware.i2c.enable exists, hardware.i2c.group defaults to "i2c", and ddcutil-2.2.7 resolves. docs/user/services/brightness.mdx confirms enable_ddcutil / sync_all_monitors / minimum_brightness (0.0-1.0) and `[brightness.monitor.<CONNECTOR>] backend = auto|none|backlight|ddcutil`. THE NIX IS BROKEN: hosts/deadPc/config.nix already defines `environment.systemPackages` at line 94 and `users.users.deadmade.extraGroups` inside the `users.users.deadmade = { … }` block at line 81. Adding either as a second top-level definition in the same attrset literal is an eval error — proven with `nix eval --impure --expr '{ e.p = [1]; e.p = [2]; }'` → "error: attribute 'e.p' already defined". (`hardware.i2c.enable = true;` alongside the existing `hardware = { … }` at line 117 IS fine — different leaf.)

**Correction:**

In hosts/deadPc/config.nix, edit in place instead:
  # line 81, was ["networkmanager" "wheel"]
  extraGroups = ["networkmanager" "wheel" "i2c"];
  # line 94, append to the existing list
  environment.systemPackages = with pkgs; [ … ddcutil ];
  # this one may be added as a new top-level attr, it does not collide:
  hardware.i2c.enable = true;
The DDC/CI answer from the Acer XB252Q remains genuinely unverified (`ddcutil detect` needs the group membership first).

### [CONFIRMED] deadConvertible: route F5/F6 brightness through noctalia msg

**Evidence:** hosts/deadConvertible/home.nix:37-41 currently has `hl.bind("SUPER + F5", hl.dsp.exec_cmd("brightnessctl set 10%-"))` / F6 `10%+`. home-manager modules/services/window-managers/hyprland.nix:378-379 types `extraConfig` as `lib.types.lines` and :524 concatenates it, so the host block appends to the shared one. `brightness-down * 5%` argument form confirmed in system-controls.mdx:60.

**Correction:**

Adjacent conflict the design does not mention, in the very file it edits: hosts/deadConvertible/home.nix:47-55 enables `services.wpaperd` on eDP-1 against ~/.config/wallpapers. That is a THIRD wallpaper daemon on that host alongside Noctalia's wallpaper service and the stylix-auto-enabled hyprpaper. Worth calling out here since this change touches the file.

### [CONFIRMED] Noctalia screenshot policy + OSD pinned to DP-3

**Evidence:** docs/user/configuration/shell.mdx:179-186 lists exactly save_to_file, directory, filename_pattern, copy_to_clipboard, freeze_screen, confirm_region, remember_last_region, show_cursor, annotate, close_on_copy, pipe_to_command, pipe_command — every key the snippet uses. `noctalia config export full` line 518 shows `annotate = false` live. shell.mdx:348 `# monitors = ["DP-1"]    # connector names; omit or leave empty for all monitors`; live `[osd]` block (line 375-388) has `monitors = []` and all 13 `[osd.kinds]` true. system-controls.mdx:65 confirms the OSD "appears on whichever monitors are configured under `[osd].monitors`".

**Correction:**

The design's own closing risk note is the correct instruction and should be promoted into the change: put `osd.monitors = ["DP-3"]` in hosts/deadPc/home.nix, NOT in the shared module. But the reason given is wrong — per the merge proof above a second definition would silently concatenate to `["DP-3" "eDP-1"]`, not error.

### [CONFIRMED] Fix the dead v4 settings (launcher_placement, calendar.cards)

**Evidence:** Live `noctalia config validate` prints exactly two warnings and nothing else: `config.toml:70:22: shell.panel.launcher_placement: unknown value "centered"` and `config.toml:27:1: calendar.cards: unknown setting`, then `✓ Config is valid (2 warning(s))`. example.toml:63 `launcher_placement = "floating" # attached | floating` and :68 `launcher_position = "center"   # auto | center | top_left | … (floating only)`; shell.mdx:234 says verbatim "`center` is a floating `*_position`, not a third placement." The `panel-toggle notifications` runtime failure is confirmed by the registerPanel list (application_ui.cpp:571-710).

**Correction:**

The brief's third alleged dead setting — the `{ id = "control-center"; useDistroLogo = true; }` object in `bar.default.end` — produces NO validator warning, so "three pieces of dead v4 syntax" is unproven. I could not confirm it is discarded; treat it as uncertain rather than repeating the claim.

### [CONFIRMED] Bar dead-zone gestures (scroll for volume, thumb buttons for media)

**Evidence:** docs/user/bar/actions.mdx:132-139 gives `[bar.default.dead_zone.actions]` with left/scroll_up/back verbatim; :29-39 fixes the gesture vocabulary as left|right|middle|back|forward|scroll_up|scroll_down|scroll_left|scroll_right and states "Any other key is a config error"; :66-73 gives the three action forms `<command> [arguments]` | `exec <cmdline>` | `none`; :88-90 contains the exact guidance the design quotes about `media toggle` over `exec playerctl play-pause`. All five verbs used (volume-up, volume-down, volume-mute, media previous, media next) are in `noctalia msg --help`. :141 confirms right click already opens the control center by default.

**Correction:**

The risk note's mitigation is unverified: `scroll_repeat` is documented as a WIDGET property (bar/index.mdx:237, actions.mdx:47 "Set `scroll_repeat` under the widget itself"), and it does not appear in the live `noctalia config export full` at all. There is no evidence a bar-level or dead_zone-level `scroll_repeat` exists. Drop that fallback or verify it before offering it.

### [CONFIRMED] Pause media on session lock (hooks.session_locked)

**Evidence:** `noctalia config export full` line 170 shows `session_locked = []` in the live `[hooks]` schema. docs/user/automation/hooks.mdx:24 `| session_locked | When the compositor confirms the session lock. |`, :10 "Each event is a shell command string or an array of shell command strings" (so the bare string is legal). media-and-ui.mdx:69-70 confirms `media pause` "No-op when nothing is playing" vs `media stop` which dismisses the player — the design's distinction is exactly right.

### [WRONG] Screen recorder: gpu-screen-recorder with a SIGINT toggle bind

**Evidence:** `nix eval` confirms `programs.gpu-screen-recorder.enable` exists on deadPc and gpu-screen-recorder-5.13.8 resolves. dispatchers.md confirms `exec_cmd` goes through `sh -c`. But that is precisely what breaks the toggle: the spawned process's own cmdline is `sh -c pkill -SIGINT -f gpu-screen-recorder || gpu-screen-recorder -w screen …`, and `pkill -f` matches full command lines, so on the FIRST press pkill matches (and SIGINTs) its own parent shell, exits 0, the `||` branch never runs, and recording never starts.

**Correction:**

Use process-name matching, not cmdline matching:
      hl.bind(mainMod .. " + SHIFT + R",
        hl.dsp.exec_cmd("pkill -SIGINT -x gpu-screen-recorder "
          .. "|| gpu-screen-recorder -w screen -f 60 -a default_output "
          .. "-o \"$HOME/Videos/$(date +%Y%m%d_%H%M%S).mp4\""),
        { description = "Toggle screen recording" })
The `-w`/`-f`/`-a` spellings for gsr 5.13 remain unverified (the package is not built here) — check `gpu-screen-recorder --help` before committing, as the design already flags.

### [CONFIRMED] User exclusions and hardware fit (no widgets/dock/hot corners, full-width bar, NVIDIA/3x1080p)

**Evidence:** Nothing in the design touches `[hot_corners]` (live schema lines 179-196), `desktop_widgets`, `[shell.screen_corners]`, or `dock` (already `enabled = false` in noctalia.nix), and `bar.default.margin_ends = 0` is untouched. Nothing added depends on VA-API (gpu-screen-recorder is the NVENC path, chosen for exactly that reason), no fprintd is assumed (`lockscreen.fingerprint = false`), and no upower/ppd is assumed to pre-exist — both are added explicitly. The 5760x1080 canvas is addressed by pinning `osd.monitors` and by using monitor-direction selectors that degrade to no-ops on u/d for a single horizontal row.

## Proposed changes

### 1. (high) CRITICAL: SUPER+L and SUPER+J each fire two dispatchers today (case-insensitive keysym collision with the vim nav keys)

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** KeybindManager.cpp v0.56.2:702-726 — for a bind whose key is a plain name, Hyprland computes `KBKEY = xkb_keysym_from_name(k->key, XKB_KEYSYM_NO_FLAGS)` AND `KBKEYLOWER = xkb_keysym_from_name(k->key, XKB_KEYSYM_CASE_INSENSITIVE)`, then matches if `key.keysym` equals EITHER. So the bind written `"L"` matches a plain `l` press (via KBKEYLOWER) and the bind written `"l"` matches it too. Lines 773-836 then push every match into `bindsHit` and run them all in the second loop — there is no first-match-wins. `hyprctl binds` confirms both are registered live: entry 14 is `modmask: 64 key: L` (lock) and entry 23 is `modmask: 64 key: l` (focus right); entry 15 is `modmask: 65 key: L` (lock-and-suspend) and entry 51 is `modmask: 65 key: l` (move window right). Same for J (entry 6 togglesplit, entry 21 focus down). Concretely: pressing SUPER+SHIFT+l to shove a window right also runs `noctalia msg session lock-and-suspend`. The fix is to vacate the single-letter SUPER layer of anything that collides case-insensitively with h/j/k/l: togglesplit moves to SUPER+T, lock moves onto the Escape cluster. Every new bind below was checked against this rule — no letter I assign on a layer that also carries h/j/k/l is one of those four letters.

**Verified against:** https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/src/managers/KeybindManager.cpp lines 702-726 (dual keysym resolve) and 773-836 (bindsHit runs all matches); live `hyprctl binds` output showing `key: L`+`key: l` and `key: J`+`key: j` both registered at modmask 64/65; KeybindManager.cpp:928-943 shows Escape is only intercepted in CLICKMODE_KILL

**Risk:** Muscle memory: SUPER+L for lock is gone. SUPER+SHIFT+escape replaces it, and the session panel on SUPER+escape has Lock on shortcut key `1`. If the user insists on keeping a letter, SUPER+CTRL+escape or SUPER+SHIFT+X are free — but any single letter reintroduces the collision unless it avoids h/j/k/l.

```nix
# REMOVE these three lines from extraConfig entirely:
#   hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
#   hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("noctalia msg session lock || loginctl lock-session"))
#   hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("noctalia msg session lock-and-suspend || systemctl suspend"))
#
# REPLACE with (T is free and does not collide with h/j/k/l;
# escape is only special-cased by Hyprland in CLICKMODE_KILL, so it is safe to bind):

      hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"),
        { description = "Toggle dwindle split" })

      hl.bind(mainMod .. " + escape",
        hl.dsp.exec_cmd(ipc .. "panel-toggle session"),
        { description = "Session menu (lock / logout / suspend / reboot / shutdown)" })
      hl.bind(mainMod .. " + SHIFT + escape",
        hl.dsp.exec_cmd(ipc .. "session lock"),
        { description = "Lock now" })
```

### 2. (high) Media, volume, mic and brightness keys — routed through noctalia msg so the OSD fires

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Nothing on deadPc binds a single XF86 key today, so all 15 enabled `[osd.kinds]` are inert. The Lua bind-options table is `{ locked = ..., repeating = ... }` — there is no `bindl`/`binde`/`bindm` spelling in the Lua config; flags are the third argument to `hl.bind()`. `locked = true` is what makes a key work while the session-lock surface is up (KeybindManager.cpp:648 skips every bind where `!k->locked && isSessionLocked()`), which is the whole point for media keys. `repeating = true` is only on the two ramp pairs (volume, brightness) — mute and track-skip must not autorepeat. Steps are left at Noctalia's default 5% (documented in ipc/system-controls.mdx): 20 presses cover the full range, which is the granularity every desktop ships. `brightness-up * 5%` uses the `*` target so one bind covers deadPc's three DDC monitors and deadConvertible's single eDP-1 backlight — `[target] [step]` is the documented argument order. `media toggle` is bound to both XF86AudioPlay and XF86AudioPause because most keyboards emit only one of the two.

**Verified against:** `noctalia msg --help` (volume-up/down/mute, mic-mute, media <next|previous|toggle|play|pause|stop|next-player|previous-player>, brightness-up/down [target] [step]); .direnv/flake-inputs/h7afg…-source/docs/user/ipc/system-controls.mdx (default step 5%, `*` target, value formats); hyprland-wiki content/configuring/core/binds/flags.md (`locked`, `repeating` are the exact flag names); /nix/store/79107j…-hyprland-0.56.2/share/hypr/hyprland.lua (shipped example uses the same XF86 key spellings)

**Risk:** On deadPc `brightness-*` is a no-op until ddcutil is enabled (see the i2c change) — /sys/class/backlight is empty. Until then the keys silently do nothing rather than erroring.

```nix
      local ipc = "noctalia msg "

      ----------------------------------------------------------------
      -- Media / volume / brightness. locked = also works on the lockscreen.
      ----------------------------------------------------------------
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up"),
        { locked = true, repeating = true, description = "Volume up" })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down"),
        { locked = true, repeating = true, description = "Volume down" })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"),
        { locked = true, description = "Mute output" })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. "mic-mute"),
        { locked = true, description = "Mute microphone" })

      hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(ipc .. "media toggle"),
        { locked = true, description = "Play / pause" })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd(ipc .. "media toggle"),
        { locked = true, description = "Play / pause" })
      hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(ipc .. "media next"),
        { locked = true, description = "Next track" })
      hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(ipc .. "media previous"),
        { locked = true, description = "Previous track" })
      hl.bind("XF86AudioStop",  hl.dsp.exec_cmd(ipc .. "media stop"),
        { locked = true, description = "Stop playback" })

      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. "brightness-up * 5%"),
        { locked = true, repeating = true, description = "Brightness up" })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down * 5%"),
        { locked = true, repeating = true, description = "Brightness down" })
```

### 3. (high) Noctalia surfaces — a coherent keymap for the six panels that are running but unbound

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** `panel-toggle notifications` in the current config is a FOURTH piece of dead syntax. The panel ids registered by Noctalia v5 are exactly `clipboard`, `session`, `test`, `control-center`, `launcher`, `wallpaper`, `tray-drawer`, `polkit`, `setup-wizard`, plus plugin ids (application_ui.cpp:571-710). `notifications` is a control-center *tab*, not a panel, so today SUPER+N does nothing. The corrected form is `panel-toggle control-center notifications`. Key choices: SUPER+A for the control centre ("Action centre"; the Noctalia docs suggest SUPER+S but S is wanted elsewhere and A is free), SUPER+SHIFT+V for clipboard next to SUPER+V float, SUPER+SHIFT+W for the wallpaper picker next to SUPER+W browser, SUPER+SHIFT+N for DND next to SUPER+N notifications, SUPER+comma for Settings (the Noctalia-documented convention, and `comma` is an unshifted key on the German layout). ALT+TAB goes to Noctalia's window switcher, which is the documented binding and needs no `[shell.window_switcher]` config; set `mru = true` for real alt-tab ordering. The launcher's emoji provider replaces wofi-emoji outright: `panel-toggle launcher /emo` is the documented query form (provider_prefix `/` + emoji prefix `emo`). Screenshots move off hyprshot to Noctalia's own capture+annotate subsystem, keeping SUPER+SHIFT+S for muscle memory and adding the Print cluster.

**Verified against:** .direnv/flake-inputs/h7afg…-source/src/app/application_ui.cpp:571-710 (registerPanel ids); src/shell/control_center/control_center_panel.h:125-137 (tab ids incl. "notifications"); docs/user/ipc/surfaces.mdx (panel-toggle launcher [query], control-center [tab]); docs/user/configuration/shell.mdx (provider_prefix "/", emoji prefix "emo", window switcher has no settings block); `noctalia msg --help` (screenshot-region / screenshot-fullscreen [mode] / screenshot-annotate / window-switcher / settings-toggle / notification-dnd-toggle / caffeine-toggle)

**Risk:** `SUPER+SHIFT+P` sits one row from SUPER+P (pseudotile) — different modmask so no collision, but a typo is a layout change rather than a colour pick. hyprpicker must be added to home.packages (see the package change).

```nix
      ----------------------------------------------------------------
      -- Noctalia surfaces
      ----------------------------------------------------------------
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"),
        { description = "Launcher" })
      hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher /emo"),
        { description = "Emoji picker" })
      hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"),
        { description = "Control center" })
      hl.bind(mainMod .. " + N",
        hl.dsp.exec_cmd(ipc .. "panel-toggle control-center notifications"),
        { description = "Notification history" })
      hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(ipc .. "notification-dnd-toggle"),
        { description = "Toggle do-not-disturb" })
      hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(ipc .. "panel-toggle clipboard"),
        { description = "Clipboard history" })
      hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(ipc .. "panel-toggle wallpaper"),
        { description = "Wallpaper picker" })
      hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(ipc .. "settings-toggle"),
        { description = "Noctalia settings" })
      hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd(ipc .. "caffeine-toggle"),
        { description = "Toggle idle inhibitor (caffeine)" })
      hl.bind("ALT + Tab", hl.dsp.exec_cmd(ipc .. "window-switcher"),
        { description = "Window switcher" })

      -- Capture (replaces hyprshot)
      hl.bind("Print", hl.dsp.exec_cmd(ipc .. "screenshot-region"),
        { description = "Screenshot: region" })
      hl.bind("SHIFT + Print", hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen"),
        { description = "Screenshot: focused monitor" })
      hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(ipc .. "screenshot-annotate"),
        { description = "Freeze screen and annotate" })
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(ipc .. "screenshot-region"),
        { description = "Screenshot: region" })
      hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"),
        { description = "Pick a colour to the clipboard" })
```

### 4. (medium) Add `shell.window_switcher.mru = true` so ALT+TAB is actually most-recently-used

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** The window switcher defaults to workspace-layout order, which makes ALT+TAB behave like a grid picker rather than a toggle between the last two windows. `mru = true` is the one knob the switcher exposes and it is what makes the ALT+TAB bind above feel like alt-tab instead of a window gallery.

**Verified against:** .direnv/flake-inputs/h7afg…-source/docs/user/configuration/shell.mdx `[shell.window_switcher] mru = false  # order windows by most recently used (Alt+Tab) instead of workspace layout`; `noctalia config export full` shows the key present in the live schema

**Risk:** None.

```nix
      shell = {
        window_switcher = {
          mru = true;
        };
      };
```

### 5. (high) Window management: mouse drag/resize, monitor moves, fullscreen variants, groups, focus-last

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** You currently cannot drag a window with the mouse at all. The Lua equivalent of `bindm` is the `{ mouse = true }` flag with a `mouse:<code>` key — 272 = LMB, 273 = RMB — and the two dispatchers are `hl.dsp.window.drag()` and `hl.dsp.window.resize()` with no arguments. The directional grammar is generated from one table so hjkl and the arrows stay in lockstep across all four layers: SUPER = focus window, SUPER+SHIFT = move window, SUPER+CTRL = resize, SUPER+ALT = monitor. Monitor selectors are directions (`l`/`r`/`u`/`d`) per the naming-conventions page, which is exactly right for a single horizontal row of three panels — u/d are harmless no-ops. 40 px is the resize step: at 1080p with scale 1 that is ~2% of width, roughly the visual size of one gaps_out(8)+gaps_in(4) pair doubled, so it is visible per press but takes ~24 presses to cross a monitor; at the live `input:repeat_rate` of 25/s a held key sweeps 1000 px/s. `SUPER+CTRL+F` uses `fullscreen_state({ internal = 2, client = 0 })` — the documented trick to fullscreen a window internally while telling the client it is not fullscreen, which stops Chromium/Electron apps entering presentation mode. Group binds finally give the Stylix-themed groupbar something to render; SHIFT+Tab is bound under both `Tab` and `ISO_Left_Tab` because layouts differ on which keysym a shifted Tab emits and only one of the two can ever match a given press.

**Verified against:** hyprland-wiki content/configuring/core/binds/devices/mouse.md (`hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })`, mouse:272/273, mouse_up/mouse_down); content/configuring/core/dispatchers.md (focus{direction|monitor|last}, window.move{direction|monitor,follow}, window.resize{x,y,relative}, fullscreen{mode="fullscreen"|"maximized"}, fullscreen_state{internal,client}, group.toggle/next/prev/lock_active); content/configuring/naming-conventions.md §Monitor (direction l/r/u/d, `current`, output name); `strings` on /nix/store/79107j…-hyprland-0.56.2/bin/.Hyprland-wrapped confirms `mouse`, `relative`, `follow`, `internal`, `client`, `keep_aspect_ratio` as live option names; live `hyprctl getoption input:repeat_rate` = 25

**Risk:** `hl.dsp.focus({ last = true })` — the wiki writes the param as `focus({ last })` without a value; `true` is the reading consistent with `out_of_group = true`, which the same table documents explicitly. If it misbehaves, drop that one line. `SUPER+ALT+SHIFT+<dir>` is three modifiers; it is the only three-modifier bind in the map and is optional.

```nix
      ----------------------------------------------------------------
      -- Mouse: drag and resize (the Lua equivalent of bindm)
      ----------------------------------------------------------------
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),
        { mouse = true, description = "Drag window" })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(),
        { mouse = true, description = "Resize window" })
      hl.bind(mainMod .. " + mouse_down", hs.dsp.focus({ workspace = "e+1" }),
        { description = "Next workspace on this monitor" })
      hl.bind(mainMod .. " + mouse_up",   hs.dsp.focus({ workspace = "e-1" }),
        { description = "Previous workspace on this monitor" })

      ----------------------------------------------------------------
      -- Directional grammar: SUPER focus / SHIFT move / CTRL resize / ALT monitor
      ----------------------------------------------------------------
      local dirs = {
        { keys = { "h", "left"  }, dir = "left",  dx = -40, dy =   0, mon = "l" },
        { keys = { "j", "down"  }, dir = "down",  dx =   0, dy =  40, mon = "d" },
        { keys = { "k", "up"    }, dir = "up",    dx =   0, dy = -40, mon = "u" },
        { keys = { "l", "right" }, dir = "right", dx =  40, dy =   0, mon = "r" },
      }

      for _, d in ipairs(dirs) do
        for _, key in ipairs(d.keys) do
          hl.bind(mainMod .. " + " .. key,
            hl.dsp.focus({ direction = d.dir }),
            { description = "Focus " .. d.dir })
          hl.bind(mainMod .. " + SHIFT + " .. key,
            hl.dsp.window.move({ direction = d.dir }),
            { description = "Move window " .. d.dir })
          hl.bind(mainMod .. " + CTRL + " .. key,
            hl.dsp.window.resize({ x = d.dx, y = d.dy, relative = true }),
            { repeating = true, description = "Resize " .. d.dir })
          hl.bind(mainMod .. " + ALT + " .. key,
            hl.dsp.focus({ monitor = d.mon }),
            { description = "Focus monitor " .. d.dir })
          hl.bind(mainMod .. " + ALT + SHIFT + " .. key,
            hl.dsp.window.move({ monitor = d.mon, follow = true }),
            { description = "Move window to monitor " .. d.dir })
        end
      end

      ----------------------------------------------------------------
      -- Fullscreen variants, groups, last window
      ----------------------------------------------------------------
      hl.bind(mainMod .. " + F",
        hl.dsp.window.fullscreen({ mode = "fullscreen" }),
        { description = "True fullscreen" })
      hl.bind(mainMod .. " + SHIFT + F",
        hl.dsp.window.fullscreen({ mode = "maximized" }),
        { description = "Maximize (keeps gaps and bar)" })
      hl.bind(mainMod .. " + CTRL + F",
        hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }),
        { description = "Fake fullscreen (client thinks it is windowed)" })

      hl.bind(mainMod .. " + TAB", hl.dsp.focus({ last = true }),
        { description = "Focus last window" })
      hl.bind(mainMod .. " + G", hl.dsp.group.toggle(),
        { description = "Toggle group (tabs)" })
      hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.lock_active(),
        { description = "Lock group" })
      hl.bind(mainMod .. " + CTRL + Tab", hl.dsp.group.next(),
        { description = "Next tab in group" })
      hl.bind(mainMod .. " + CTRL + SHIFT + Tab", hl.dsp.group.prev(),
        { description = "Previous tab in group" })
      hl.bind(mainMod .. " + CTRL + SHIFT + ISO_Left_Tab", hl.dsp.group.prev(),
        { description = "Previous tab in group" })
```

### 6. (medium) Resize submap on SUPER+R

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** SUPER+CTRL+hjkl covers quick nudges; a submap covers a deliberate resize session without holding two modifiers. It reuses the same `dirs` table so the direction semantics never drift from the main map. SHIFT inside the submap multiplies the step by 4 (160 px ≈ 8% of width) for coarse framing. Both `escape` and `return` exit — a submap with only one exit is how people get stranded. I deliberately did NOT add `hl.bind("catchall", hl.dsp.submap("reset"))`: KeybindManager.cpp:699-701 gates catchall on `found`, but `found` is only set in the second (execution) loop, so a catchall registered alongside real binds can fire *in addition to* them rather than instead.

**Verified against:** hyprland-wiki content/configuring/core/binds/submaps.md (exact `hl.define_submap("resize", function() … hl.bind("escape", hl.dsp.submap("reset")) end)` shape, and `hl.dsp.window.resize({ x = 10, y = 0, relative = true })` with `{ repeating = true }`); /nix/store/79107j…/share/hypr/stubs/hl.meta.lua:825 `define_submap fun(name: string, reset_or_fn: string|function, fn?: function)`; KeybindManager.cpp:699-701 for the catchall caveat

**Risk:** If you get stranded: `hyprctl dispatch 'hl.dsp.submap("reset")'` from any terminal, per the wiki. Home Manager also exposes a declarative `wayland.windowManager.hyprland.submaps` option if you would rather not hand-write this — but it requires wrapping every dispatcher in `lib.generators.mkLuaInline`, which is uglier than the raw Lua here.

```nix
      hl.bind(mainMod .. " + R", hl.dsp.submap("resize"),
        { description = "Resize mode" })

      hl.define_submap("resize", function()
        for _, d in ipairs(dirs) do
          for _, key in ipairs(d.keys) do
            hl.bind(key,
              hl.dsp.window.resize({ x = d.dx, y = d.dy, relative = true }),
              { repeating = true })
            hl.bind("SHIFT + " .. key,
              hl.dsp.window.resize({ x = d.dx * 4, y = d.dy * 4, relative = true }),
              { repeating = true })
          end
        end
        hl.bind("escape", hl.dsp.submap("reset"))
        hl.bind("return", hl.dsp.submap("reset"))
      end)
```

### 7. (medium) Scratchpad on SUPER+minus / SUPER+SHIFT+minus (resolves the SUPER+SHIFT+S collision)

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** The canonical Hyprland pair is SUPER+S / SUPER+SHIFT+S, but SUPER+SHIFT+S is the screenshot bind with years of muscle memory behind it and screenshots are used far more often than a scratchpad. Moving the scratchpad to `minus` is the i3/sway convention (`$mod+minus` show, `$mod+shift+minus` move to scratchpad), collides with nothing, and `minus` is an unmodified key on the German layout (the key right of `.`). Note the asymmetry that trips people up: `toggle_special` takes a bare name and adds the `special:` prefix itself, while `window.move` takes any workspace and therefore needs the prefix written out.

**Verified against:** hyprland-wiki content/configuring/core/dispatchers.md §Special workspaces — verbatim `hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))` / `hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))` plus the note that only special-workspace dispatchers add the prefix themselves; /nix/store/79107j…/share/hypr/hyprland.lua ships the same pair

**Risk:** If you would rather have S: move screenshots to the Print cluster only and take SUPER+S / SUPER+SHIFT+S back. Both work; this is purely a muscle-memory call.

```nix
      hl.bind(mainMod .. " + minus",
        hl.dsp.workspace.toggle_special("scratch"),
        { description = "Toggle scratchpad" })
      hl.bind(mainMod .. " + SHIFT + minus",
        hl.dsp.window.move({ workspace = "special:scratch" }),
        { description = "Move window to scratchpad" })
```

### 8. (high) Window rules: idle-inhibit for fullscreen video and games, float the Noctalia settings window

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** The repo has zero window rules, so once the idle ladder below is switched on a film or a game will lock the screen mid-play. `idle_inhibit = "fullscreen"` applied to `class = ".*"` is one rule that covers every fullscreen surface — Noctalia's idle manager uses `ext_idle_notifier_v1` and explicitly respects active idle inhibitors, so the compositor-side inhibitor is enough and no caffeine dance is needed. A second rule with `idle_inhibit = "focus"` catches VLC playing in a maximised-but-not-fullscreen window. Firefox/LibreWolf already raise a real Wayland idle inhibitor for video, so it needs no rule. The Noctalia settings window is an ordinary xdg-toplevel with app_id `dev.noctalia.Noctalia` and will tile into the dwindle layout without this rule — worth having now that SUPER+comma opens it. Note on escaping: this is inside a Nix `''…''` string where `\` is not an escape character, so `\\.` in the Nix file reaches Lua as `\\.` and Lua's parser yields the regex `\.` — correct.

**Verified against:** hyprland-wiki content/configuring/core/rules/window-rules.md — `idle_inhibit` values `"none"|"always"|"focus"|"fullscreen"`, `size` `{800, 600}`, `center`, `float`, and the match keys `class`/`initial_class` (snake_case, confirmed against the binary's string table which has `initial_class` and not `initialClass`); .direnv/flake-inputs/h7afg…-source/docs/user/compositor-settings/hyprland.mdx ships the identical `dev.noctalia.Noctalia` float rule; docs/user/services/idle.mdx "Idle behavior uses the Wayland ext_idle_notifier_v1 protocol and respects active idle inhibitors"

**Risk:** `idle_inhibit = "fullscreen"` on `.*` also inhibits idle for a fullscreen terminal you walked away from. That is the standard trade and is why the desktop's screen-off timeout stays modest.

```nix
      ----------------------------------------------------------------
      -- Rules
      ----------------------------------------------------------------
      -- Films and games must not be interrupted by the idle ladder.
      hl.window_rule({
        name  = "idle-inhibit-fullscreen",
        match = { class = ".*" },
        idle_inhibit = "fullscreen",
      })
      hl.window_rule({
        name  = "idle-inhibit-players",
        match = { class = "^(vlc|mpv)$" },
        idle_inhibit = "focus",
      })

      -- Noctalia's Settings window (SUPER+comma) is a normal toplevel.
      hl.window_rule({
        name  = "noctalia-settings",
        match = { class = "^dev\\.noctalia\\.Noctalia$" },
        float  = true,
        center = true,
        size   = { 1080, 920 },
      })
```

### 9. (medium) Compositor settings that make the mouse binds and workspace wheel usable

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** `binds.scroll_event_delay` is at its 300 ms default (verified live with `hyprctl getoption`), which makes SUPER+wheel workspace switching feel broken — a wheel detent burst is 50-80 ms apart, so 300 ms swallows most of a flick. 120 ms lets you step deliberately without one flick jumping four workspaces. `workspace_back_and_forth` is explicitly supported by the vendored hyprsplit library (it reads `hl.get_config("binds.workspace_back_and_forth")` and falls back to `previous_per_monitor`), so turning it on gives per-monitor toggle-to-last-workspace for free. `resize_on_border` + `extend_border_grab_area` mean you can grab a window edge without holding SUPER — with border_size 2 and gaps_in 4 the raw hit area is 2 px, so the 15 px grab extension is what makes it real. `snap.enabled` makes windows dragged with the new SUPER+LMB bind snap to each other and to monitor edges.

**Verified against:** /nix/store/79107j…/share/hypr/stubs/hl.meta.lua:1337-1366 (HL.ConfigOpt.General fields incl. resize_on_border, extend_border_grab_area, hover_icon_on_border, snap) and :1628-1642 (HL.ConfigOpt.Binds incl. scroll_event_delay, workspace_back_and_forth); live `hyprctl getoption binds:scroll_event_delay` → `int: 300 set: false`; ~/.config/hypr/hyprsplit/init.lua lines ~220-235 read `binds.workspace_back_and_forth`

**Risk:** `resize_on_border` can make edge clicks resize instead of focusing in apps with thin chrome; if that annoys, drop `extend_border_grab_area` back to the default 15→smaller or turn the pair off.

```nix
        general = {
          layout = "dwindle";
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;

          # Drag a window edge to resize without holding SUPER. border_size is 2px,
          # so the grab area has to be extended to be hittable.
          resize_on_border = true;
          extend_border_grab_area = 15;
          hover_icon_on_border = true;

          snap = {
            enabled = true;
          };
        };

        binds = {
          # Default 300ms makes SUPER+wheel workspace switching feel stuck.
          scroll_event_delay = 120;
          # hyprsplit reads this and routes to previous_per_monitor.
          workspace_back_and_forth = true;
        };
```

### 10. (high) Fix SUPER+E: thunar is not installed — yazi in ghostty, Nautilus on SHIFT+E

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** `fileManager._var = "thunar"` points at a binary that does not exist on either host (`command -v thunar` is empty; nothing in the repo installs it). Nautilus IS installed via modules/nixos/desktop/packages.nix but is unbound. For a terminal-heavy tmux user the right default is yazi: it opens instantly, it inherits the terminal's colours (so Noctalia's ghostty template themes it for free, no GTK/libadwaita recolouring problem at all), and it lives in the same keyboard idiom as the rest of the setup. Nautilus stays for the cases a TUI genuinely loses — dragging a file into a browser upload, and mounting/trash via the already-enabled gvfs. Do NOT pick Thunar (needs xfconf + tumbler, and `services.tumbler.enable = false` here so thumbnails would be dead), Nemo (drags in Cinnamon plumbing), or Dolphin (does not exist as a top-level attr in this nixpkgs — it is `kdePackages.dolphin`, and it would pull a large chunk of KDE). Note that `vars.browser = "helium"` and `vars.terminal = "kitty"` in flake/modules/constants.nix are both stale relative to what this host actually runs, so keep using local `_var`s here rather than wiring `vars` in.

**Verified against:** `command -v thunar` empty on the live host; `grep -rn thunar` in the repo only matches config.nix:9; modules/nixos/desktop/packages.nix:22 installs `nautilus`; `nix eval .#nixosConfigurations.deadPc.pkgs.dolphin.name` errors while `nemo`/`yazi` resolve; flake/modules/constants.nix shows vars.browser="helium", vars.terminal="kitty"

**Risk:** `ghostty -e yazi` inherits ghostty's default working directory rather than the focused window's cwd. If that matters, bind it to a wrapper that reads the active window's cwd instead.

```nix
# In wayland.windowManager.hyprland.settings:
      terminal._var = "ghostty";
      browser._var = "librewolf";
      fileManager._var = "ghostty -e yazi";

# In extraConfig, replacing the two hardcoded "librewolf" strings too:
      hl.on("hyprland.start", function()
        hl.exec_cmd(browser)
      end)

      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal),
        { description = "Terminal" })
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser),
        { description = "Browser" })
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager),
        { description = "File manager (yazi)" })
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus --new-window"),
        { description = "File manager (GUI)" })
```

### 11. (medium) New module: enable yazi

**File:** `modules/home-manager/terminal/yazi.nix`

**Rationale:** yazi is not installed anywhere today. Dropping the file into modules/home-manager/terminal/ makes it auto-discovered by flake/lib/registry.nix and live on the next rebuild, because profiles/home-manager/desktop-dev.nix imports the whole terminal domain with `builtins.attrValues outputs.homeManagerModules.terminal` — so both desktop hosts get it with no profile edit. It must be `git add`ed before it is visible to flake evaluation.

**Verified against:** /nix/store/v573js…-source/modules/programs/yazi.nix exists in the pinned home-manager; `nix eval .#nixosConfigurations.deadPc.pkgs.yazi.name` → yazi-26.5.6; CLAUDE.md §"To add a new module"; profiles/home-manager/desktop-dev.nix uses builtins.attrValues on the terminal domain

**Risk:** Stylix has a yazi target (stylix/modules/yazi), so yazi will be Stylix-coloured rather than Noctalia-coloured. Given decision #1 demotes Stylix, either accept the mismatch or disable `stylix.targets.yazi.enable` and let the ghostty template carry the colours — that call belongs to the colour-authority domain.

```nix
{...}: {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };
}
```

### 12. (medium) Package set: drop hyprshot and wofi-emoji, add hyprpicker

**File:** `modules/home-manager/windowManager/hyprland/default.nix`

**Rationale:** hyprshot duplicates Noctalia's screenshot+annotate subsystem (which is themed, has an editor, and honours a single `[shell.screenshot]` output policy), and wofi-emoji duplicates the launcher's `/emo` provider while being the one unthemed window left on the desktop. hyprpicker is currently only reachable as a subprocess inside the hyprshot wrapper and needs to be a first-class package now that SUPER+SHIFT+P calls it directly. `hyprpicker -a` copies the picked colour straight to the clipboard, which is the only sane default when Noctalia owns clipboard history.

**Verified against:** modules/home-manager/windowManager/hyprland/default.nix:19-23 (current list); `nix eval .#nixosConfigurations.deadPc.pkgs.hyprpicker.name` → hyprpicker-0.4.7; `noctalia msg --help` (screenshot-region/annotate) and docs/user/configuration/shell.mdx §[shell.screenshot]

**Risk:** Separately: `services.network-manager-applet.enable = true` here duplicates Noctalia's network widget in the tray (as do blueman and solaar). Removing it is a one-line cleanup but it is a different domain's call — leaving it in place costs nothing but a duplicate tray icon.

```nix
    home.packages = with pkgs; [
      hyprpicker # colour picker, bound to SUPER+SHIFT+P
      networkmanagerapplet
    ];
```

### 13. (high) Turn on Noctalia's own polkit agent — GUI privilege prompts silently fail today

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `security.polkit.enable = true` in modules/nixos/core/security.nix, but no agent registers on org.freedesktop.PolicyKit1, so any GUI action needing authentication just does nothing. Noctalia's agent is a real, complete agent — not a stub: `ldd` on the built binary shows it linked against libpolkit-agent-1.so.0, libpolkit-gobject-1.so.0 and libpam.so.0, and the source has src/dbus/polkit/polkit_agent.cpp + polkit_session_support.cpp + src/shell/polkit/polkit_panel.cpp with a registered `polkit` panel. Using it instead of hyprpolkitagent keeps the prompt inside Noctalia's palette, which matters under decision #1. There is NO conflict with gnome-keyring: gnome-keyring provides org.freedesktop.secrets, not a polkit agent — and it is in fact a dependency for the clipboard panel this design binds, because Noctalia encrypts clipboard history with a Secret-Service-stored master key. `security.pam.services.login.enableGnomeKeyring` and `.greetd.` both evaluate to true on deadPc, so the keyring unlocks at login and the clipboard history persists. The `polkit_placement`/`polkit_position` defaults (floating/center) are already what you want on a 5760px canvas.

**Verified against:** `ldd /nix/store/qiipyv…-noctalia-5.0.1/bin/.noctalia-wrapped | grep -iE 'polkit|pam'` → libpolkit-agent-1.so.0, libpolkit-gobject-1.so.0, libpam.so.0; .direnv/flake-inputs/h7afg…-source/meson.build:86-87,485-486,691 (polkit deps and sources compiled in); src/app/application_ui.cpp:707 registerPanel("polkit", …); docs/user/configuration/shell.mdx (`polkit_agent` "register Noctalia's native polkit authentication agent", placement/position semantics); `nix eval` of security.pam.services.{login,greetd}.enableGnomeKeyring → true

**Risk:** If Noctalia crashes or is restarted mid-prompt the prompt is lost — an out-of-process agent like hyprpolkitagent survives a shell restart. Given Noctalia runs as a systemd user unit with Restart=on-failure, this is acceptable; if it bites, `hyprpolkitagent` is the fallback and `polkit_agent = false` is a one-line revert.

```nix
      shell = {
        # security.polkit.enable = true but nothing registered on
        # org.freedesktop.PolicyKit1. Noctalia's agent is a full
        # polkit-agent-1 + PAM implementation, and it is themed.
        polkit_agent = true;
        panel = {
          polkit_placement = "floating";
          polkit_position = "center";
        };
      };
```

### 14. (high) Idle ladder: desktop (deadPc) — 15 min lock, 20 min screens off, no suspend

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** All three seeded behaviours are `enabled = false` today, so the machine never locks, blanks or suspends — on a nix-mineral-hardened host that is the single largest gap between the security posture the config claims and what it does. 900 s to lock is the workstation standard (CIS/DISA STIG both use 15 minutes for a fixed workstation): short enough to matter, long enough that reading a long document does not lock you out. Screen-off at 1200 s is five minutes after lock; three 27" IPS panels draw roughly 25-30 W each, so blanking recovers ~80 W without being twitchy. `locked_timeout = 60` is the piece most ladders miss: once you have *deliberately* locked with SUPER+SHIFT+escape, the panels go dark in a minute instead of waiting out the full 20. Suspend stays disabled on this host on purpose — it runs emulated aarch64/riscv64 builds via `boot.binfmt.emulatedSystems`, nh's cleaner, and Tailscale; suspending mid-build costs more than the idle watts. `pre_action_fade_seconds = 5.0` is the warning: the overlay is click-through and any activity cancels the pending command, so 2 s (the current default) is barely perceptible while 5 s is a human reaction window. The parser accepts 0-120 and the Settings stepper offers 0-30. Note `behavior_order` is a LIST, so it must be defined exactly once — put it here in the shared module and let hosts override only the scalar leaves (attrsOf merges recursively; lists do not).

**Verified against:** .direnv/flake-inputs/h7afg…-source/docs/user/services/idle.mdx (behavior_order, pre_action_fade_seconds range 0-120, actions lock/screen_off/suspend/lock_and_suspend/command, lock_before_suspend); src/idle/idle_manager.h:45 "While locked, behaviors with a positive lockedTimeoutSeconds re-arm at that shorter timeout" and idle_manager.cpp:95-96; src/config/schema/config_schema.cpp:907 field name `locked_timeout`; `noctalia config export full` lines 199-225 showing all three seeded and disabled; docs/user/configuration/shell.mdx §Lock screen for `fingerprint`

**Risk:** Suspend disabled means the desktop idles at full power indefinitely. If the user would rather it sleep overnight, enable the suspend rung with a long timeout (e.g. 7200) — but a `systemd-inhibit`-aware build wrapper would be the safer route. The dot in `screen-off` is fine in Nix as a bare attr name because it is a hyphen, not a dot.

```nix
      # Shared: the ladder exists and fades before it fires.
      idle = {
        behavior_order = ["lock" "screen-off" "suspend"];
        pre_action_fade_seconds = 5.0;

        behavior = {
          lock = {
            enabled = true;
            action = "lock";
            timeout = 900;
          };
          screen-off = {
            enabled = true;
            action = "screen_off";
            timeout = 1200;
            locked_timeout = 60;
          };
          suspend = {
            enabled = false; # desktop: overridden on the laptop
            action = "lock_and_suspend";
            timeout = 900;
          };
        };
      };

      lockscreen = {
        # deadPc has no fprintd device: "[fingerprint] no fprintd device".
        fingerprint = false;
        # true by default; locks on logind PrepareForSleep, incl. lid close.
        lock_before_suspend = true;
      };
```

### 15. (high) Idle ladder: laptop (deadConvertible) — 5 / 6 / 15 minutes

**File:** `hosts/deadConvertible/home.nix`

**Rationale:** A laptop leaves the house, so its posture is mobile-device rather than fixed-workstation: 300 s to lock is the standard for a device that can be picked up. Screen-off 60 s later (360 s) and `locked_timeout = 30` because on battery the panel is the largest single draw. Suspend at 900 s with `lock_and_suspend`. This works as a host override without restating the whole block because `programs.noctalia.settings` is typed `oneOf [tomlFormat.type str path]`, and `lib.types.either` dispatches to `(attrsOf valueType).merge` when every definition is an attrset — so nested attrsets merge recursively across modules. Only lists (like `behavior_order` or `bar.default.end`) would collide, which is why `behavior_order` lives in the shared module and is not repeated here.

**Verified against:** .direnv/flake-inputs/h7afg…-source/nix/home-module.nix:41-76 (settings option type); /nix/store/bx7ivh…-source/lib/types.nix:1488-1507 (serializableValueWith → oneOf incl. attrsOf valueType) and the `either` merge rule at :1517+; docs/user/services/idle.mdx

**Risk:** Noctalia's lockscreen authenticates against the PAM service `login` (src/auth/pam_authenticator.cpp:180-197 — the service defaults to "login" and there is no config key to change it), so fingerprint on the lockscreen needs `services.fprintd.enable = true` AND fprintd wired into the `login` PAM stack, not just the Noctalia toggle.

```nix
  programs.noctalia.settings.idle.behavior = {
    lock.timeout = 300;
    screen-off = {
      timeout = 360;
      locked_timeout = 30;
    };
    suspend = {
      enabled = true;
      timeout = 900;
    };
  };

  # Flip to true only if `lsusb`/`fprintd-list deadmade` shows a reader,
  # and pair it with services.fprintd.enable = true on the host.
  programs.noctalia.settings.lockscreen.fingerprint = false;
```

### 16. (medium) deadPc daemons: upower + power-profiles-daemon

**File:** `hosts/deadPc/config.nix`

**Rationale:** Two logged failures come from missing daemons. `[upower] GetDisplayDevice failed … not activatable` — there is no upower on this host. `[power] power profiles refresh failed` — the Control Center's power_profile shortcut and the `power-set`/`power-cycle` IPC verbs need `org.freedesktop.UPower.PowerProfiles`, which power-profiles-daemon owns. Do NOT drop the battery widget to silence this: the widget already "hides itself when the selected battery is missing or not present", so it costs nothing on a desktop — and once upower is running it becomes useful here, because `hardware.logitech.wireless.enable = true` on this host means the Logitech mouse/keyboard batteries appear as UPower devices that a second battery widget can target with an explicit `device` selector. power-profiles-daemon does work on a desktop Ryzen 3900X: `inputs.hardware.nixosModules.common-cpu-amd-pstate` is already imported, Zen 2 supports CPPC, and ppd drives amd_pstate EPP. Both daemons are small and neither conflicts with anything here (no TLP in the tree). Worth binding `power-cycle` once ppd is up.

**Verified against:** `grep -rn upower/power-profiles` across the repo → only hosts/deadConvertible/config.nix:78-79; `nix eval` confirms `services.upower.enable` and `services.power-profiles-daemon.enable` are bool options on deadPc; .direnv/flake-inputs/h7afg…-source/docs/user/bar/widgets/battery.mdx "Hides itself when the selected battery is missing or not present" and "device = auto is safe on desktops"; docs/user/ipc/system-controls.mdx §Power profile "Requires org.freedesktop.UPower.PowerProfiles"; hosts/deadPc/config.nix:152 hardware.logitech.wireless.enable

**Risk:** power-profiles-daemon conflicts with services.tlp — not present here. If amd_pstate is running in passive mode ppd will expose fewer profiles; check with `powerprofilesctl list` after the rebuild.

```nix
  # Noctalia logs "[upower] GetDisplayDevice failed … not activatable" and
  # "[power] power profiles refresh failed" without these.
  # upower also surfaces the Logitech wireless peripherals' batteries.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
```

### 17. (medium) deadPc brightness: ddcutil over i2c (there is no backlight on a desktop)

**File:** `hosts/deadPc/config.nix`

**Rationale:** `/sys/class/backlight` is empty on deadPc, so the XF86MonBrightness binds above are inert until DDC/CI is enabled. The eight `/dev/i2c-*` nodes already exist and `i2c_dev` is loaded, but they are `crw-rw---- root:root` and there is no `i2c` group — so ddcutil cannot run unprivileged. `hardware.i2c.enable = true` creates the group and the udev rules; the user has to be added to it. This is safe under nix-mineral: the compatibility preset sets `kernel-modules.enable = false`, so no module blacklisting or `kernel.modules_disabled` is in play. `sync_all_monitors = true` is the right call for three identical-role panels — one keypress moves all three together instead of only whichever monitor has the pointer.

**Verified against:** live `ls /sys/class/backlight/` → empty; `ls -la /dev/i2c-*` → crw-rw---- root, 8 nodes; `getent group i2c` → rc=2 (no group); `lsmod | grep i2c` → i2c_dev loaded; `nix eval` confirms `hardware.i2c.enable` (bool) and `hardware.i2c.group` (str) exist; .direnv/flake-inputs/h7afg…-source/docs/user/services/brightness.mdx (`enable_ddcutil`, `sync_all_monitors`, `minimum_brightness`, per-monitor `backend = auto|none|backlight|ddcutil`); .direnv/flake-inputs/81n9pr…-source/presets/compatibility.nix:75 `kernel-modules.enable = false`

**Risk:** UNVERIFIED: whether these three specific panels answer DDC/CI over the NVIDIA driver's i2c buses. HP V27e almost certainly does; the Acer XB252Q has a G-Sync module and those are known to be unreliable on DDC. Confirm after rebuild with `ddcutil detect` (as the user, once in the i2c group); the docs note ddcutil is best-effort and Noctalia cools down monitors that repeatedly fail. If DP-3 misbehaves, the per-monitor `backend = "none"` line above opts it out.

```nix
# hosts/deadPc/config.nix
  # No /sys/class/backlight on a desktop. /dev/i2c-* exist but are root-only
  # and there is no i2c group, so ddcutil needs both of these.
  hardware.i2c.enable = true;
  environment.systemPackages = [pkgs.ddcutil];

  users.users.deadmade.extraGroups = ["networkmanager" "wheel" "i2c"];

# hosts/deadPc/home.nix
  programs.noctalia.settings.brightness = {
    enable_ddcutil = true;
    sync_all_monitors = true;
    minimum_brightness = 0.1; # never let the desk go pitch black
    # If the Acer XB252Q's G-Sync module refuses DDC, opt it out:
    # monitor.DP-3.backend = "none";
  };
```

### 18. (medium) deadConvertible: unify brightness onto Noctalia, drop the direct brightnessctl binds

**File:** `hosts/deadConvertible/home.nix`

**Rationale:** SUPER+F5/F6 currently call `brightnessctl` directly, which changes the backlight without Noctalia ever hearing about it — so no OSD, and the Control Center brightness slider drifts out of sync until its next poll. Routing them through `noctalia msg brightness-down/up` keeps the muscle memory, fires the OSD, and keeps the slider truthful. The laptop's Fn keys should also emit XF86MonBrightness{Up,Down} natively, which the shared binds now handle — these two lines are the fallback for a laptop whose firmware does not.

**Verified against:** hosts/deadConvertible/home.nix:37-41 (current brightnessctl binds); .direnv/flake-inputs/h7afg…-source/docs/user/ipc/system-controls.mdx §Brightness (targets `current|all|*|<connector>`, values `65|65%|0.65`); home-manager modules/services/window-managers/hyprland.nix:378-379 `extraConfig` is `types.lines`, so the host block concatenates with the shared one

**Risk:** `brightnessctl` can stay in hosts/deadConvertible/config.nix:92 — Noctalia's backlight backend writes sysfs itself and does not shell out to it, but it is harmless and useful for scripts.

```nix
    extraConfig = ''
      -- Fn-key fallback for laptops whose firmware does not emit
      -- XF86MonBrightness*. Routed through Noctalia so the OSD fires and the
      -- Control Center slider stays in sync (brightnessctl bypassed both).
      hl.bind("SUPER + F5", hl.dsp.exec_cmd("noctalia msg brightness-down * 5%"),
        { locked = true, repeating = true, description = "Brightness down" })
      hl.bind("SUPER + F6", hl.dsp.exec_cmd("noctalia msg brightness-up * 5%"),
        { locked = true, repeating = true, description = "Brightness up" })
    '';
```

### 19. (medium) Noctalia screenshot output policy + OSD on the centre monitor only

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** The old hyprshot bind was `--clipboard-only`; Noctalia's defaults save AND copy, so state the policy explicitly rather than inheriting it. Keeping both is the better default now that there is an annotation editor in the path — the file is the undo for a clipboard you overwrite thirty seconds later. `freeze_screen = true` (default) matters on a 240 Hz panel where an unfrozen region select tears. On the OSD: `[osd].monitors` is empty, so every volume nudge pops three identical toasts across a 5760 px canvas. Pinning it to DP-3 (the centre 240 Hz panel, the one you actually look at) makes it read as one piece of feedback; the docs guarantee a fallback to all outputs if that connector is ever disconnected. I checked whether `position = "top_center"` collides with the full-width top bar and it does not — the OSD layer surface is created with `exclusiveZone = 0` (osd_overlay.cpp:499), which means it respects other surfaces' exclusive zones, and the bar's `reserve_space` is true, so the OSD lands just below the bar automatically. Leave the position alone.

**Verified against:** .direnv/flake-inputs/h7afg…-source/docs/user/configuration/shell.mdx §[shell.screenshot] (every key above, plus "At least one of save_to_file, copy_to_clipboard, or pipe_to_command must be enabled") and §OSD ([osd].monitors semantics and fallback); src/shell/osd/osd_overlay.cpp:495-499 (LayerShellLayer::Overlay, exclusiveZone = 0); example.toml:359 bar `reserve_space = true`

**Risk:** `monitors = ["DP-3"]` is host-specific and this file is shared with deadConvertible (eDP-1). Put the `osd.monitors` line in hosts/deadPc/home.nix instead of the shared module — it is a list, so a second definition in the shared file would collide rather than merge.

```nix
      shell = {
        screenshot = {
          save_to_file = true;
          copy_to_clipboard = true;
          freeze_screen = true;   # 240Hz panel: unfrozen region select tears
          annotate = false;       # SUPER+Print reaches the editor on demand
          show_cursor = false;
          directory = "/home/${vars.username}/Pictures/screenshots";
          filename_pattern = "screenshot_%Y%m%d_%H%M%S";
        };
      };

      osd = {
        # 5760x1080: without this, every volume nudge pops three toasts.
        # DP-3 is the centre panel. Docs: falls back to all outputs if the
        # listed connector is disconnected.
        monitors = ["DP-3"];
      };
```

### 20. (medium) Fix the three (now four) dead v4 settings the config validator is already warning about

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `noctalia theme --list-templates` prints the warnings on every invocation: `config.toml:70:22: shell.panel.launcher_placement: unknown value "centered"` and `config.toml:27:1: calendar.cards: unknown setting`. `launcher_placement` accepts only `attached` or `floating` — `center` is a `*_position`, not a placement — so the intent ("launcher in the middle of the screen") is expressed as floating + center, which is already the default. The `calendar.cards` list is gone in v5. And the fourth, which nothing warns about because it is a *runtime* failure rather than a config one, is the SUPER+N bind to `panel-toggle notifications` — a panel id that does not exist (fixed in the keymap change above).

**Verified against:** live `noctalia theme --list-templates` stderr: two config warnings at config.toml:70:22 and :27:1; .direnv/flake-inputs/h7afg…-source/docs/user/configuration/shell.mdx "launcher_placement … accept only attached or floating. … center is a floating *_position, not a third placement"; src/app/application_ui.cpp:571-710 (no `notifications` panel registered)

**Risk:** Removing `calendar.cards` restores the calendar content in the clock popup. If it must stay hidden, the widget-actions route above is the supported way; `[bar.default.actions]`/`[widget.<name>.actions]` are the documented override layers.

```nix
      shell = {
        panel = {
          # v5: placement is attached|floating; "center" is a *_position.
          # These two are already the defaults; keep them only as documentation
          # of intent, or drop the block entirely.
          launcher_placement = "floating";
          launcher_position = "center";
        };
      };

      # DELETE the whole `calendar = { cards = [...]; }` block — the key does not
      # exist in v5 and is reported as "unknown setting". To hide calendar content,
      # rebind the clock widget's left click instead:
      #   [widget.clock.actions] left = "panel-toggle control-center home"
```

### 21. (low) Bar dead-zone gestures — scroll the empty bar for volume, thumb buttons for media

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Decision #2 makes the bar span the full screen edge-to-edge, which means there is a lot of dead zone between the capsules — and Noctalia lets the uncovered bar take the same gesture bindings any widget takes. Scrolling anywhere on the bar to change volume is the single cheapest "this feels finished" affordance available, and thumb-button media control costs nothing. I deliberately leave `left` unbound: an accidental left click on a full-width bar opening the launcher would be maddening. Right click already opens the control centre at the pointer by default. Actions are IPC verbs by default — `exec` is only for things the verb list does not cover, and the docs are explicit that `media toggle` is the right way to pause playback rather than `exec playerctl play-pause`.

**Verified against:** .direnv/flake-inputs/h7afg…-source/docs/user/bar/actions.mdx §"The dead zone" (verbatim `[bar.default.dead_zone.actions]` with left/scroll_up/back), §Gestures (the fixed nine-key vocabulary), §Actions (`<command> [arguments]` | `exec <cmdline>` | `none`, and the "reach for exec only when nothing in that list covers what you want" guidance); `noctalia msg --help` for volume-up/down/mute and `media <action>`

**Risk:** Scroll gestures quantize per detent by default (`scroll_repeat = "auto"` treats volume as a ramp), so a fast flick can move volume several steps. Set `scroll_repeat = "gesture"` on the bar if that is too twitchy.

```nix
      bar = {
        default = {
          dead_zone = {
            actions = {
              scroll_up = "volume-up";
              scroll_down = "volume-down";
              middle = "volume-mute";
              back = "media previous";
              forward = "media next";
              # left deliberately unbound: a full-width bar makes stray
              # left clicks far too easy.
            };
          };
        };
      };
```

### 22. (low) Pause media when the session locks (Noctalia hook)

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `[hooks]` fires shell commands on shell events, and `session_locked` is one of them. Pausing playback when the screen locks is the small courtesy that stops a podcast playing to an empty room after the 15-minute idle lock. Using `noctalia msg media pause` rather than `playerctl pause` keeps it inside the MPRIS player Noctalia has already selected (and avoids adding playerctl, which nothing else needs). `media pause` rather than `media stop` because stop also dismisses the player from the media widget. No unlock hook: resuming automatically on unlock is the wrong default.

**Verified against:** .direnv/flake-inputs/h7afg…-source/docs/user/automation/hooks.mdx (`session_locked` "When the compositor confirms the session lock", and the worked example `session_locked = ["playerctl pause", "noctalia msg bar-hide"]`); docs/user/ipc/media-and-ui.mdx §Media (`media pause` "Pause the active MPRIS player. No-op when nothing is playing" vs `media stop` which dismisses the player)

**Risk:** None — it is a no-op when nothing is playing.

```nix
      hooks = {
        session_locked = "noctalia msg media pause";
      };
```

### 23. (low) Screen recorder: gpu-screen-recorder (NVENC) with a toggle bind

**File:** `hosts/deadPc/config.nix`

**Rationale:** OBS is installed but it is a session, not a capture key. On an RTX 3070, gpu-screen-recorder is the right tool over wf-recorder/wl-screenrec because it encodes on NVENC with near-zero CPU cost and works on the NVIDIA proprietary driver; the others target VA-API. NixOS ships `programs.gpu-screen-recorder.enable`, which handles the setcap on gsr-kms-server that the tool needs for KMS capture — installing the package alone is not enough. The bind is a start/stop toggle rather than two binds because you never remember which state you are in.

**Verified against:** `nix eval` confirms `programs.gpu-screen-recorder.enable` is a bool option on deadPc; `nix eval .#nixosConfigurations.deadPc.pkgs.gpu-screen-recorder.name` → gpu-screen-recorder-5.13.8; hyprland-wiki content/configuring/core/dispatchers.md §"Executing with rules" confirms exec_cmd goes through `sh -c` so the `||` and `$(…)` work

**Risk:** UNVERIFIED: the exact `-w`/`-a` argument spelling for gsr 5.13 — check `gpu-screen-recorder --help` before committing. `-w screen` captures the whole 5760x1080 canvas; use a connector name (`-w DP-3`) to record one monitor. SUPER+SHIFT+R sits next to SUPER+R (resize mode) but the modmasks differ so there is no collision.

```nix
# hosts/deadPc/config.nix
  # Sets up gsr-kms-server with the capabilities it needs; installing the
  # package alone is not sufficient.
  programs.gpu-screen-recorder.enable = true;

# modules/home-manager/windowManager/hyprland/config.nix (extraConfig)
      hl.bind(mainMod .. " + SHIFT + R",
        hl.dsp.exec_cmd("pkill -SIGINT -f gpu-screen-recorder "
          .. "|| gpu-screen-recorder -w screen -f 60 -a default_output "
          .. "-o \"$HOME/Videos/$(date +%Y%m%d_%H%M%S).mp4\""),
        { description = "Toggle screen recording" })
```

## Open questions

**1. Security posture for the idle timeouts (the task asks explicitly).** I proposed deadPc = lock at 15 min / screens off at 20 min (60 s once already locked) / no suspend, and deadConvertible = 5 / 6 / 15 min with suspend on. Three questions behind that: (a) Is deadPc physically in a household with other people, or a private room? If private, 15 min is arguably paranoid for a machine whose real threat model is remote, and 30 min is defensible; if not, 10 min is the harder line. (b) Should the desktop ever suspend? I said no because of binfmt-emulated aarch64/riscv builds and Tailscale, but if it idles overnight the power case is real — I would want a `systemd-inhibit`-wrapped build alias first. (c) nix-mineral is on `preset = "compatibility"`, which is explicitly the desktop-friendly posture — should the idle ladder match that pragmatism, or be the one place the hardening actually bites?

**2. SUPER+L muscle memory.** The collision fix forces lock off the letter L. I put the session panel on SUPER+escape and lock on SUPER+SHIFT+escape. If SUPER+L must survive, the only safe way is to drop `l` from the vim focus row (keeping arrows) — a much bigger behavioural change. Which do you want?

**3. Scratchpad vs screenshot on SUPER+SHIFT+S.** I kept screenshot there and put the scratchpad on `minus` (i3 convention). The alternative is moving screenshots to the Print cluster only and taking the canonical SUPER+S / SUPER+SHIFT+S pair back.

**4. Does deadConvertible have a fingerprint reader?** I set `lockscreen.fingerprint = false` in the shared module because deadPc logs `[fingerprint] no fprintd device`. If the laptop has one, it needs `services.fprintd.enable = true` AND fprintd in the `login` PAM stack — Noctalia's authenticator hardcodes the service name `login` (src/auth/pam_authenticator.cpp:180-197), it is not configurable.

**5. Do the three monitors answer DDC/CI?** The brightness keys on deadPc are inert without it. HP V27e should be fine; the Acer XB252Q's G-Sync module is the risk. Needs a `ddcutil detect` after `hardware.i2c.enable` + group membership land. If DP-3 refuses, `[brightness.monitor.DP-3].backend = "none"` opts it out cleanly.

**Things I could not verify:** the `{ last = true }` spelling for `hl.dsp.focus` (the wiki writes the param as bare `{ last }`); the gpu-screen-recorder 5.13 CLI flags; whether a shifted Tab emits `Tab` or `ISO_Left_Tab` under Hyprland's non-`resolve_binds_by_sym` translation state (I bound both, which is safe since only one keysym can match a given press). Also worth flagging as an unrelated stray: `security.pam.services.hyprland.enableGnomeKeyring = true` in modules/nixos/core/security.nix targets a PAM service nothing uses — hyprlock is not installed and Noctalia's lockscreen uses `login`.
