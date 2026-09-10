# Lock, session, startup

_Login, lock, and session (greeter, lockscreen, session menu, startup, GRUB, session plumbing)_

Noctalia Greeter is real, packaged, and cached in this flake's own nixpkgs (`pkgs.noctalia-greeter` 1.3.1, narinfo 200 on cache.nixos.org) — migrate to it. But it has one hard prerequisite that is currently missing: `services.displayManager.sessionPackages` evaluates to `[]` and `/run/current-system/sw/share/wayland-sessions` does not exist, so the greeter's session picker would be empty; `programs.hyprland.enable = true` (pinned to `pkgs.unstable.hyprland` to match Home Manager) must land first, and it also buys the `cap_sys_nice` wrapper Hyprland never gets today. The colour link is the greeter's `scheme = "Synced"` with **no** `[appearance.palette]` in Nix — a complete palette in `greeter.toml` permanently outranks what Sync writes, which would freeze the greeter while the desktop regenerates from every wallpaper. Beyond the greeter: the lock screen's login box renders regardless of `lockscreen_widgets.enabled` (verified in `lock_surface.cpp`), so the three stale state entries are live today; and session plumbing is genuinely healthy — `loginctl` reports a seat0 wayland session, all targets active — so the plumbing changes are for the greeter and for frame pacing, not to fix a break.

## Fatal problems flagged by the verifier

Nothing in this design breaks the build or eval as written -- `nix flake check` would survive all thirteen items, and the two Noctalia option surfaces I could not find in `config export full` (shell.greeter_sync.privilege_command, and the whole greeter.toml key set) both turned out to be REAL, verified in config_schema.cpp:1507 and in the greeter binary's own emitted template header. No fourth piece of dead v4 syntax is being added. Three things will break the SESSION or the user's expectations, though, and must be fixed before this is built:

1. hooks.started = ["librewolf"] (change 10) is a live regression, not a polish. hook_manager.cpp:37 -> application_ipc.cpp:789 process::runAsync makes librewolf an ordinary child of noctalia.service, so KillMode=control-group kills the browser on every `nhs` that touches noctalia settings (the HM unit carries X-Restart-Triggers on config.toml, nix/home-module.nix:104-109), and every restart -- including the unit's own Restart=on-failure -- fires `started` again and opens a second browser. Drop this line; keep the existing hl.on("hyprland.start").

2. The greeter prerequisite's stated verification is wrong and will look like a failed rebuild. /run/current-system/sw/share/wayland-sessions is never created by any NixOS module (no /share/wayland-sessions in environment.pathsToLink; services/display-managers/default.nix:203-204 exports sessionData.desktops only through environment.sessionVariables.XDG_DATA_DIRS, and greetd is not among the modules that consume it). The change still works -- pam_env in /etc/pam.d/greetd delivers XDG_DATA_DIRS to the greeter, which searches $XDG_DATA_DIRS/*/wayland-sessions -- but if the plan tells you to check that /run path after rebooting, you will conclude the migration failed and roll back a working generation. Fix the rationale and the check.

3. The whole "the greeter reuses your avatar via AccountsService" story (changes 2 and 11) does not happen declaratively. setIconFile is only ever reached from applyAvatarPath, whose only two callers are the Control Center picker (home_tab.cpp:260) and a Settings mutation (settings_window_mutations.cpp:118). A Nix-set shell.avatar_path is never pushed to AccountsService. Either drop services.accounts-daemon.enable = true, or keep it and add the one-time manual avatar pick to the plan as an explicit step.

Two lower-stakes corrections worth folding in: the GRUB item reaches the right answer from two false premises (fontSize = 48 is already inert on deadPc -- `nix eval` shows grub.font is still the default unicode.pf2 -- and Stylix's grub target does set a full boot_menu theme, not just a background colour), and the greeter risk note has greetd's restart policy backwards (greetd.nix:113 is Restart="on-success", so a crashing greeter fails rather than looping, and tty2-6 remain available).

Genuinely unverifiable from here, and correctly flagged by the design: whether noctalia-greeter's bundled wlroots 0.20 compositor can drive the NVIDIA 595.99.02 proprietary driver pre-login. hardware.nvidia.modesetting.enable evaluates true, but the only test is a reboot -- do it with `nixos-rebuild boot` and keep the tuigreet generation, exactly as proposed.

## Verdicts

### [WRONG] Enable Hyprland at the NixOS level (modules/nixos/desktop/hyprland.nix)

**Evidence:** Option names + version claims all check out: nixpkgs hyprland.nix:21 (package), :36 (portalPackage, apply=genFinalPackage{hyprland=cfg.package}), :51 (xwayland.enable), :55 (withUWSM), :93-96 (security.wrappers.Hyprland cap_sys_nice+ep), :102 (extraPortals), :107 (sessionPackages). `nix eval` -> {"stable":"0.55.4","unstable":"0.56.2","portalStable":"1.3.12","portalUnstable":"1.4.1"}. Override-is-a-no-op proven: `nix eval` -> {"hyprHasXW":true,"hyprSame":true,"portalHasHypr":true,"portalSame":true} (so BOTH applies are cached, incl. the `package` apply the design never mentioned). BUT the central mechanism claim is false: NOTHING in nixpkgs links /share/wayland-sessions into the system path. `nix eval ...environment.pathsToLink` has no /share/wayland-sessions entry, and services/display-managers/default.nix:203-204 exports `installedSessions` ONLY as environment.sessionVariables.XDG_DATA_DIRS; grep of nixos/modules for sessionData.desktops shows only sddm/gdm/ly/lightdm/lemurs/plasma/dms-greeter consume it -- greetd does not. So /run/current-system/sw/share/wayland-sessions will STILL not exist after this change. Duplicate-portal severity is also overstated: system-path.nix:211 `ignoreCollisions = true`, so two portal versions is a silent arbitrary winner, not an eval error.

**Correction:**

Keep the snippet exactly as written -- it is correct Nix and the picker WILL work, but by a different route: /etc/pam.d/greetd already contains `session required ...pam_env.so conffile=/etc/pam/environment` and /etc/pam/environment line 23 sets PATH starting with /run/wrappers/bin, so the greeter process inherits XDG_DATA_DIRS=${sessionData.desktops}/share from pam_env and finds the session through its `$XDG_DATA_DIRS/*/wayland-sessions` search arm. Rewrite the rationale accordingly, and change the post-rebuild verification step from `ls /run/current-system/sw/share/wayland-sessions` (which will fail and look like a regression) to `nix eval --raw .#nixosConfigurations.deadPc.config.services.displayManager.sessionData.desktops` then `ls <that>/share/wayland-sessions`. The cap_sys_nice payoff does survive: start-hyprland uses execvp (strings shows `execvp`, no absolute path), and pam_env puts /run/wrappers/bin first on PATH.

### [CONFIRMED] Replace tuigreet with Noctalia Greeter (modules/nixos/desktop/greeter.nix)

**Evidence:** pkgs.noctalia-greeter version 1.3.1 (nix eval), outPath /nix/store/g2kns1bc856dsm910qami6rj4xkjjfkf-noctalia-greeter-1.3.1 already realised locally. mainProgram=noctalia-greeter-session, so `lib.getExe` gives the right greetd entry point (bin/ has all 5 binaries; noctalia-greeter-session is the sh wrapper that starts compositor+greeter). EVERY greeter.toml key is confirmed from the binary's own emitted template header (`strings bin/noctalia-greeter`): `# [session] default, [user] default` / `# [appearance] scheme, password_style, hide_logo, power_buttons_position, scheme_selector_position, theme_mode, corner_radius_scale, font_family` / `# [output] name/layout/scale/scales/width/height/transforms, [idle] timeout, [cursor] theme/size/path` / `# [keyboard] layout/variant/options/numlock` / `# [auth] allow_empty_password (bool), request_timeout (0-3600 seconds; default 60...)`. Enum strings present: "Synced", "hidden", "top-right", "bottom-left", "bottom-right". Session search paths present verbatim: "/usr/local/share/wayland-sessions","/usr/share/wayland-sessions","wayland-sessions","/run/current-system/sw/share/way...", plus XDG_DATA_DIRS. Disconnect fallback confirmed: "output '{}' is not connected; showing on all outputs". Default state dir "/var/lib/noctalia-greeter" + "greeter.toml"/"sync.toml" strings present; packaged lib/tmpfiles.d/noctalia-greeter.conf is `d /var/lib/noctalia-greeter 0750 greeter greeter -`. Nix side: config.stylix.cursor.{package,name,size} and stylix.fonts.sansSerif.name are all set in modules/nixos/desktop/stylix.nix:31-33,35-38; vars.keyboardLayout="de" in flake/modules/constants.nix:14; systemd.tmpfiles.settings.<name>.<path>.<type>.{mode,user,group,age,argument} confirmed in nixos/modules/system/boot/systemd/tmpfiles.nix:38-125; `attrs ? ${expr}` is legal Nix. Registry gives outputs.nixosModules.desktop.greeter automatically (flake/lib/registry.nix) and deadPc imports nixosProfiles.desktopAll which does `builtins.attrValues outputs.nixosModules.desktop`.

**Correction:**

Two rationale fixes, no snippet change. (1) The risk text says "greetd restarts on failure, so a crashing greeter loops rather than dropping to a shell" -- wrong. greetd.nix:113 is `Restart = lib.mkIf cfg.restart "on-success"`. A crashing greeter leaves greetd failed, not looping; tty1 has no getty (greetd.nix:84 disables autovt@tty1) but Ctrl+Alt+F2..F6 still give a login. That is a BETTER recovery story than stated -- but still do `nixos-rebuild boot` + reboot. (2) The `services.accounts-daemon.enable = true` justification does not hold (see the avatar verdict); keep the line only if you also do the one-time UI avatar pick, otherwise drop it.

### [CONFIRMED] Delete the tuigreet greetd blocks from both hosts

**Evidence:** hosts/deadPc/config.nix:95 `tuigreet` in environment.systemPackages, :104-114 the services.greetd block with `user = "deadmade"`. hosts/deadConvertible/config.nix:89 tuigreet, :103-116 the equivalent block. Conflict claim is right: greetd.nix:26-27 `settings = mkOption { type = settingsFormat.type; }` (freeform TOML), so two normal-priority `default_session.command` definitions is an eval error. greetd.nix:76 `default_session.user = lib.mkDefault "greeter"`, :149-154 users.users.greeter/users.groups.greeter, :145-147 tmpfiles `d '/var/cache/tuigreet' - greeter greeter - -` -- so the tuigreet cache genuinely never worked under user=deadmade. The ANSI-theme claim is backed by /proc/cmdline, which carries vt.default_red/grn/blu Catppuccin palettes. deadConvertible really does cherry-pick (config.nix:17-26 lists desktop.bluetooth/packages/stylix/vpn/ai/jetbrains/tailscale/wayvnc -- no desktop.base, no desktopAll), so the explicit `outputs.nixosModules.desktop.hyprland` + `.greeter` imports are required.

### [CONFIRMED] Passwordless polkit rule for greeter appearance sync

**Evidence:** The packaged policy at share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy annotates `org.freedesktop.policykit.exec.path` with the literal store path /nix/store/g2kns1bc856dsm910qami6rj4xkjjfkf-noctalia-greeter-1.3.1/bin/noctalia-greeter-apply-appearance and defaults allow_active to auth_admin -- exactly what the rule overrides. /share/polkit-1 IS in the evaluated environment.pathsToLink, so environment.systemPackages registers the action. security.polkit.enable evaluates true on deadPc. Helper resolution: greeter_appearance_sync.cpp:111-121 findApplyHelper -> resolveProgramPath -> canonicalExecutablePath (:105-112, std::filesystem::canonical) so the /run/current-system/sw/bin symlink resolves to that same store path. isTrustedPrivilegeExecutable (:114-143) requires uid0 non-group/other-writable regular file and a root-owned parent chain where group/other-writable is only tolerated with S_ISVTX -- `stat` gives `drwxr-xr-x root root /`, `drwxr-xr-x root root /nix`, `drwxrwxr-t root nixbld /nix/store`, so the sticky bit is what saves it, exactly as claimed. Legacy path confirmed by docs/user/configuration/shell.mdx:553-560 (passwordless needs greeter >=1.5.0 AND a post-5.0.1 shell; nixpkgs has 1.3.1 and the shell is 5.0.1).

### [CONFIRMED] Turn on greeter sync from the shell, forced through pkexec

**Evidence:** `privilege_command` is real despite being absent from `noctalia config export full` -- config_schema.cpp:1507-1515 parses it and only re-serialises it when non-empty, which is why the export shows a bare `[shell.greeter_sync] auto_sync = false`. Documented in docs/user/configuration/shell.mdx:625-628 table (auto_sync bool default false; privilege_command string default ""). resolvePrivilegeEscalator does prefer run0: process.cpp:745-753 `if (commandExists("run0")) return "run0"; if (commandExists("pkexec")) return "pkexec";` and /run/current-system/sw/bin/run0 -> systemd-260.2/bin/run0 exists. With the override, greeter_appearance_sync.cpp:878-891 takes the hasPrivilegeCommandOverride branch and buildPrivilegedApplyCommand (:857-874) emits `pkexec '<helper>' '<staging>'` with no env prefix, because legacyStateEnvironment (:850-856) returns nullopt for the default /var/lib/noctalia-greeter. appearanceSyncAvailable at :953-957 matches the description. Busy/single-flight at :966-972.

**Correction:**

One caveat worth carrying into the plan text: docs/user/configuration/shell.mdx:623 says "Leave privilege_command empty for the normal action-specific policy" -- that sentence is about CONSTRAINED (1.5.0) sync, where pkexec is already the hardcoded escalator. In the legacy path you are actually on, run0 wins by default, so the override is required. Say so explicitly or a future reader will delete the line on the strength of that doc sentence.

### [CONFIRMED] Configure the lock screen: capture, blur 0.75, tint 0.45, fingerprint off

**Evidence:** `noctalia config export full` lines 247-256 give exactly [lockscreen] with allow_empty_password/blur_intensity 0.5/blurred_desktop false/enabled/fingerprint true/lock_before_suspend/monitors []/tint_intensity 0.3/wallpaper "". docs/user/configuration/shell.mdx:395-425 confirms every semantic claim word for word: "Capture each output before lock and use it as the lock screen background", "The snapshot lives in memory only until unlock", "If capture fails ... falls back to the normal per-output wallpaper", `wallpaper` "Ignored when desktop capture is active", and `monitors` "Empty shows it on all outputs; listed-only mode leaves other outputs black". Section name is [lockscreen], not [lock_screen].

### [CONFIRMED] Make the machine actually lock when idle

**Evidence:** `noctalia config export full` lines 199-224: [idle] behavior_order = ["lock","screen-off","lock-and-suspend"], pre_action_fade_seconds = 2.0, and [idle.behavior.lock]/[idle.behavior.screen-off]/[idle.behavior.lock-and-suspend] each with action/command/enabled/locked_timeout/resume_command/timeout, all enabled=false today. Defaults are 600/660/900, matching the design's cited example. The Nix attr spelling (`behavior.lock`, `behavior."screen-off"`, `behavior."lock-and-suspend"`) maps 1:1 onto those TOML tables. Suspend-is-costly rationale is real: hosts/deadPc/config.nix:22-25 sets boot.binfmt.emulatedSystems = ["aarch64-linux" "riscv64-linux"].

**Correction:**

Minor type hygiene: the schema field is a double (config_schema.cpp:906 `field(&IdleBehaviorConfig::timeoutSeconds, "timeout")`, exported as 600.0). toml++ does convert TOML integers to double via value<T>, so `timeout = 600` should work, but I could not exercise it (no file writes allowed in this session). Write `timeout = 600.0;` / `900.0;` in the Nix to make it a TOML float and remove the doubt entirely.

### [CONFIRMED] Session panel: 3x2 grid, six actions, countdowns on the destructive two

**Evidence:** docs/user/configuration/shell.mdx:507-528 gives the field table: action (lock|logout|suspend|lock_and_suspend|reboot|shutdown|command), enabled, command ("required" for action="command"), label, glyph, shortcut, countdown_seconds, variant (default|primary|secondary|destructive|outline). :530 "Omitting [[shell.session.actions]] entirely keeps the default five actions. To define your own list, declare one or more tables" -- confirms the wholesale-replacement risk note. :503 grid_columns "(1-5)" so 3 is legal. session_action_meta.cpp:20-27 isKnown includes "command"; :50-68 defaultGlyph returns "suspend" for BOTH suspend and lock_and_suspend, and glyph_registry.cpp:78-81 aliases shutdown->power, reboot->refresh, suspend->player-pause -- so the collision the design fixes is real. Both custom glyphs exist: python check of assets/fonts/tabler.json (5958 keys) -> zzz True, moon True, lock/logout/power/refresh True. `noctalia msg --help` lists `dpms-off  Turn monitors off`. Live export confirms session_placement="attached" and show_shortcuts=true are already the defaults.

### [CONFIRMED] Bind the session panel to SUPER+SHIFT+E

**Evidence:** docs/user/ipc/surfaces.mdx:32 `panel-toggle session` -> "Open or close the logout, reboot, and shutdown menu"; `noctalia msg --help` lists panel-toggle. No collision: the full bind table in modules/home-manager/windowManager/hyprland/config.nix uses SHIFT only with Q, S, L, arrows, h/j/k/l and digits 0-9 -- SHIFT+E is free. Lua form matches the generated file: ~/.config/hypr/hyprland.lua:113-120 shows `hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))` etc., same spelling the snippet uses. canonicalActionName mapping confirmed at session_action_meta.cpp:70-78 ("lock-and-suspend" -> lock_and_suspend), so the existing SUPER+SHIFT+L bind is fine as-is.

### [WRONG] Compose the startup: no wizard, fade first wallpaper, autostart via hooks.started

**Evidence:** The three options are all real -- docs/user/configuration/shell.mdx:41,196 (setup_wizard_enabled), docs/user/desktop/wallpaper.mdx + export line 663 (transition_on_startup = false), docs/user/automation/hooks.mdx:11-20 ("Each event is a shell command string or an array of shell command strings"; `started` = "Once after Noctalia finishes startup (IPC ready)"). But moving librewolf into hooks.started is a regression. hook_manager.cpp:37 calls the runner set at application_services.cpp:847 -> Application::runShellCommand -> application_ipc.cpp:789-795 `process::runAsync(command)`, i.e. an ordinary child of the noctalia process. noctalia runs as a systemd user unit whose Unit.X-Restart-Triggers include the generated config.toml (noctalia nix/home-module.nix:104-109) and whose Service has `Restart = "on-failure"` (:113). Under the default KillMode=control-group, (a) every `nhs` that touches noctalia settings kills your browser, and (b) every noctalia restart -- config change or crash -- fires `started` again and opens ANOTHER librewolf. Separately, the stated benefit is already moot on deadPc: ~/.local/state/noctalia/.setup-complete exists, so the wizard cannot auto-open there today.

**Correction:**

Keep `setup_wizard_enabled = false;` (still correct for deadConvertible / any reinstall) and `transition_on_startup = true;`. DROP `hooks.started = ["librewolf"];` and leave the existing `hl.on("hyprland.start", function() hl.exec_cmd("librewolf") end)` in config.nix. If the layer-shell race is worth solving, solve it inside Hyprland instead, e.g. `hl.exec_cmd("sh -c 'until noctalia msg bar-show >/dev/null 2>&1; do sleep 0.2; done; exec librewolf'")`, or accept the race -- one reflow at login is cheaper than a browser that dies on every home-manager switch.

### [WRONG] Fix the broken avatar (avatar_path -> store path)

**Evidence:** The mechanical facts hold: ~/.face does not exist (ENOENT), modules/home-manager/assets/avatar.jpg exists (15k), and `${../../assets/avatar.jpg}` from modules/home-manager/windowManager/hyprland/noctalia.nix is the correct depth (the same file already uses ../../../../wallpapers for the repo root). The AccountsService rationale does not. src/shell/profile/avatar_path.cpp:153-192 shows setIconFile is reached only through applyAvatarPath, and grep of the whole tree gives exactly two callers: control_center/tabs/home_tab.cpp:260 (the avatar file picker) and settings/settings_window_mutations.cpp:118 (a Settings write). Nothing runs it at startup for a config-declared value, and applyAvatarPath finishes by writing the path into settings.toml via setOverride -- a route a Nix-declared value never takes. resolvedAvatarPath (:136-147) merely PREFERS config.shell.avatarPath over accounts->iconFile() for the shell's own UI. So a declarative avatar_path will never populate IconFile, and services.accounts-daemon.enable = true on its own buys the greeter nothing.

**Correction:**

Keep `avatar_path = "${../../assets/avatar.jpg}";` -- it correctly fixes the shell's own dangling path. But rewrite the rationale, and either (a) drop `services.accounts-daemon.enable = true` from greeter.nix, or (b) keep it and add an explicit one-time manual step to the plan: after the first rebuild, open Control Center -> user card -> pick modules/home-manager/assets/avatar.jpg, which is what actually calls SetIconFile (it also writes shell.avatar_path into settings.toml, which will then shadow the Nix value -- expected, and harmless since both point at the same image).

### [CONFIRMED] Resolve the stale lockscreen login-box state

**Evidence:** The counter-intuitive core claim is exactly right. lock_surface.cpp:1585-1595 `isLoginBoxEnabled()` returns true when m_config is null OR when findForOutput yields no entry, and reads only `loginBox->enabled` -- never lockscreenWidgets.enabled; :1573-1583 resolveLoginStyle is the same shape; :963-979 does the geometry override (panelX = cx - panelWidth*0.5, panelY = cy - panelHeight*0.5) with the default at `panelY = max(spaceLg, sh - panelHeight - 84.0F)`. So the three stale entries in ~/.local/state/noctalia/settings.toml (verified present: widget_order + three lockscreen-login-box@DP-2/DP-3/HDMI-A-1 tables with cy=961.0, background_opacity=0.88, background_radius=12.0, input_radius=6.0) are live now. Every field name in the snippet matches `config export full` lines 258-351 exactly (type, output, enabled, cx, cy, box_width, box_height, placement_width, placement_height, rotation, and the 14 settings keys). Precedence risk is real: docs/user/configuration/index.mdx:101-103 "Because settings.toml loads last, it wins". Re-drift path is real: lockscreen_widgets_controller.cpp:204-209 does set enabled=true and persist it when the editor opens.

**Correction:**

One number is unjustified. The rendered panel height is NOT box_height -- lock_surface.cpp:962,975 compute it from `defaultPanelHeight(loginStyle.layout, showSession, showInfoConfigured)`, and box_height is never read for placement (only box_width is, via resolvePanelWidth). So the design's "196 px panel ... 402 above and 482 below" arithmetic is derived from a value the renderer ignores, and setting show_weather=false changes the real height. Keep cy = 500.0 as a deliberate move-up-from-961, but drop the fake 55/45 justification and plan to eyeball it once after the state file is cleared.

### [WRONG] GRUB: leave stylix.targets.grub.enable = false (no change)

**Evidence:** Right conclusion, two wrong reasons. (1) fontSize=48 is ALREADY dead, not something stylix would break: nixpkgs grub.nix:579-586 defaults `font` to `${realGrub}/share/grub/unicode.pf2`, :588-596 documents fontSize as "Ignored unless font is set to a ttf or otf font", and :138-139 takes the `.pf2` passthrough branch so convertedFont (the only consumer of fontSize, :147-159) is never built. `nix eval` on deadPc confirms it: {"font":"/nix/store/nxgbnri4sklbwvy3axg2grcpfnsnh2ja-grub-2.12/share/grub/unicode.pf2","fontSize":48,"appSize":12,"grubTarget":false}. Enabling the stylix target would, if anything, be the first time a size is honoured at all. (2) "It only paints backgroundColor + a 1x1 splash pixel: not a theme" is false -- stylix modules/grub/nixos.nix:66-125 also sets boot.loader.grub.theme to a generated derivation with a full theme.txt: desktop-image/desktop-color, a terminal box, a `+ progress_bar` with fonts.sansSerif and base0B/base05, and a `+ boot_menu` with item_height 40, item_font, item_color base05 and selected_item_color base01. Only the third reason (re-pinning boot to Catppuccin while the desktop goes wallpaper-derived) actually survives. Plymouth aside is factually grounded: /proc/cmdline carries `quiet` and `loglevel=0`, and greetd.nix:41-49 has greeterManagesPlymouth.

**Correction:**

Keep the decision (leave stylix.targets.grub.enable = false) but replace the reasoning with: (a) it re-pins the boot menu to a static Catppuccin palette at the exact moment the desktop stops being Catppuccin -- the only reason that holds; and (b) note as a separate, unrelated cleanup that `boot.loader.grub.fontSize = 48` in modules/nixos/core/grub2-bootloader.nix has never done anything, and needs `boot.loader.grub.font = "${pkgs.<fontpkg>}/share/fonts/.../X.ttf"` (a ttf/otf, not the default .pf2) to take effect.

### [CONFIRMED] Session plumbing: nothing is broken today

**Evidence:** Reproduced live. `loginctl list-sessions` -> session 3, UID 1000, SEAT seat0, LEADER 4333, CLASS user, TTY tty1 (plus the uid manager session 2). `systemctl --user is-active graphical-session.target hyprland-session.target noctalia.service` -> active/active/active. XDG_CURRENT_DESKTOP=Hyprland, XDG_SESSION_TYPE=wayland. The chain is visible in the generated config: ~/.config/hypr/hyprland.lua:96-97 `hl.on("hyprland.start", ...)` running dbus-update-activation-environment --systemd && systemctl --user stop/start hyprland-session.target. PAM claim verified directly against /etc/pam.d/greetd, which contains `session optional ...pam_systemd.so` and `session required ...pam_env.so conffile=/etc/pam/environment`. The uwsm-picker warning is real: /nix/store/79107j882v0qnrb4jwhf4q8sipp0fbjr-hyprland-0.56.2/share/wayland-sessions/ contains BOTH hyprland.desktop (Name=Hyprland, Exec=.../bin/start-hyprland) and hyprland-uwsm.desktop (Name=Hyprland (uwsm-managed)) regardless of withUWSM, which is why pinning [session].default = "Hyprland" matters.

## Proposed changes

### 1. (high) Enable Hyprland at the NixOS level (hard prerequisite for any greeter with a session picker)

**File:** `modules/nixos/desktop/hyprland.nix`

**Rationale:** Verified blocker: `nix eval` of deadPc gives `services.displayManager.sessionPackages` length 0, and `/run/current-system/sw/share/wayland-sessions` does not exist. noctalia-greeter searches exactly `/usr/local/share/wayland-sessions`, `/usr/share/wayland-sessions`, `/run/current-system/sw/share/wayland-sessions` and `$XDG_DATA_DIRS/*/wayland-sessions` (src/greeter/greeter_sessions.cpp:81-94) — the only hyprland.desktop on this box is in `~/.nix-profile/share/wayland-sessions`, which the `greeter` user cannot reach (/home/deadmade is 0700). `programs.hyprland.enable` sets `services.displayManager.sessionPackages = [ cfg.package ]`, which is the one thing that populates that directory. Second, independent payoff: it adds `security.wrappers.Hyprland` with `cap_sys_nice+ep`, which Hyprland uses to give itself SCHED_RR at startup — today the compositor runs without it, which matters most on the 240 Hz DP-3 panel. `package` MUST be `pkgs.unstable.hyprland`: `pkgs.hyprland` is 0.55.4 here while HM runs 0.56.2, and a mismatch means the .desktop Exec and the setcap wrapper point at a different binary than the one whose `hyprland.lua` HM generates. `portalPackage` must be the *unstable* portal because the option's `apply` unconditionally runs `genFinalPackage p { hyprland = cfg.package; }` — I verified `pkgs.unstable.xdg-desktop-portal-hyprland.override { hyprland = pkgs.unstable.hyprland; }` has an outPath identical to the un-overridden package (so: cached, no source rebuild), whereas overriding the 26.05 portal (1.3.12) would force a local build. UWSM is deliberately off: HM's module already emits `dbus-update-activation-environment --systemd ... && systemctl --user stop/start hyprland-session.target`, and `hyprland-session.target` has `BindsTo = graphical-session.target` (BindsTo implies Requires), which is what actually pulls up graphical-session.target and starts noctalia.service. Adding uwsm's `wayland-session@Hyprland.target` on top gives two mechanisms racing to own the same target for zero gain.

**Verified against:** nix eval of deadPc config (sessionPackages=0, dmEnable=true); ls /run/current-system/sw/share/wayland-sessions -> ENOENT; /nix/store/bx7ivhrfvs5263ryip99zkc1v0x853i2-source/nixos/modules/programs/wayland/hyprland.nix and lib.nix (genFinalPackage); nix eval proving base.outPath == override outPath for pkgs.unstable.xdg-desktop-portal-hyprland; ~/.nix-profile/share/wayland-sessions/hyprland.desktop (Name=Hyprland)

**Risk:** programs.hyprland adds xdg-desktop-portal-hyprland to xdg.portal.extraPortals, which modules/nixos/desktop/base.nix (deadPc) and hosts/deadConvertible/config.nix already do with the *26.05* package. Drop `xdg-desktop-portal-hyprland` from both of those extraPortals lists in the same commit so only one portal version is registered. deadConvertible cherry-picks modules and does not use desktop-all, so it needs an explicit `outputs.nixosModules.desktop.hyprland` import line; deadPc picks the new file up automatically via `builtins.attrValues outputs.nixosModules.desktop` in profiles/nixos/desktop-all.nix — but only once the file is `git add`ed.

```nix
{pkgs, ...}: {
  # Hyprland is started by greetd, but nothing at the NixOS level knows about
  # it: services.displayManager.sessionPackages is empty and
  # /run/current-system/sw/share/wayland-sessions does not exist, so a greeter
  # with a session picker (noctalia-greeter) sees no sessions at all.
  programs.hyprland = {
    enable = true;

    # Must be the same compositor Home Manager configures
    # (modules/home-manager/windowManager/hyprland/default.nix uses
    # pkgs.unstable.hyprland = 0.56.2). pkgs.hyprland here is 0.55.4; two
    # versions would mean the generated hyprland.lua, the wayland-sessions
    # Exec= and the cap_sys_nice wrapper all point at different binaries.
    package = pkgs.unstable.hyprland;

    # portalPackage has an `apply` that always runs
    # genFinalPackage p { hyprland = cfg.package; }. Handing it the unstable
    # portal makes that override a no-op (identical outPath => cached);
    # handing it the 26.05 portal would rebuild it from source.
    portalPackage = pkgs.unstable.xdg-desktop-portal-hyprland;

    xwayland.enable = true;

    # HM's systemd.enable already drives hyprland-session.target ->
    # graphical-session.target -> noctalia.service. UWSM would add a second,
    # competing session manager for the same target.
    withUWSM = false;
  };
}
```

### 2. (high) Replace tuigreet with Noctalia Greeter (new shared NixOS module)

**File:** `modules/nixos/desktop/greeter.nix`

**Rationale:** `pkgs.noctalia-greeter` is 1.3.1 in this flake's nixpkgs, `mainProgram = noctalia-greeter-session`, and its narinfo returns 200 from cache.nixos.org (no build). Its NAR listing shows all five binaries plus `share/polkit-1/actions/org.noctalia.greeter.apply-appearance.policy` and `lib/tmpfiles.d/noctalia-greeter.conf`. There is NO noctalia module in nixpkgs' module-list.nix, and the upstream project's `nixosModules.default` fills `programs.noctalia-greeter.package` from *its own* nixos-unstable input — importing it would build a second greeter from source — so the ~15 lines are hand-rolled here, which also matches CLAUDE.md's "no custom mkOption, compose by importing" rule. Key design decision: `scheme = "Synced"` with **no** `[appearance.palette]`. The greeter's own docs are explicit that greeter.toml beats sync.toml, so a palette pinned in Nix would outrank Sync forever and freeze the login screen on one palette while the desktop regenerates from each new wallpaper — the exact mismatch this migration exists to remove. `[output].name = "DP-3"` pins the greeter to the 240 Hz centre panel: the compositor then disables the other connectors at KMS, which avoids modesetting three monitors before login, and the docs guarantee it "falls back to showing on all outputs" if that connector is disconnected, so it cannot lock you out. `width`/`height` 1920x1080 pin the DRM mode to what the session uses, which is what stops the modeset flash on handoff (by default the greeter picks the EDID-preferred size at the *highest* refresh, i.e. 240 Hz on DP-3, then Hyprland re-modesets). `idle.timeout = 300` blanks the greeter after 5 min instead of burning a static login box into an idle panel. `hide_logo = true` because this is a NixOS box, not a Noctalia billboard. `scheme_selector_position = "hidden"` because `[appearance].scheme` in greeter.toml overrides whatever the picker writes to sync.toml — the control would be visibly inert. Fonts and cursor are read straight off `config.stylix.*` so they cannot drift from the desktop (Stylix keeps fonts + cursor after its demotion, so this is exactly the right coupling). `services.accounts-daemon.enable = true` because Noctalia pushes `avatar_path` into AccountsService IconFile so the greeter can reuse it — /home/deadmade is 0700, so the greeter user has no other way to see an avatar; it currently evaluates to false.

**Verified against:** nix eval .#nixosConfigurations.deadPc.pkgs.noctalia-greeter.version -> 1.3.1; curl cache.nixos.org/g2kns1bc856dsm910qami6rj4xkjjfkf.narinfo -> 200; the .ls NAR listing (5 binaries + polkit policy + tmpfiles.d); noctalia-greeter-1.3.1/nix/nixos-module.nix, examples/greeter.toml, docs/user/configuration.md; src/greeter/greeter_config_io.cpp:62-64,88,92 (key names); nixpkgs pkgs/by-name/no/noctalia-greeter/package.nix (mainProgram); nix eval (accounts-daemon.enable=false, modesetting.enable=true)

**Risk:** The single real unknown: noctalia-greeter runs its own wlroots 0.20 compositor, and this is the first thing on this box to drive KMS on the NVIDIA proprietary driver before login (tuigreet is a TTY app and never touched the GPU). `hardware.nvidia.modesetting.enable` evaluates to true and /dev/dri/card1 exists, so it should work, but it is unverifiable without rebooting. Do this one with `nixos-rebuild boot` + reboot (which CLAUDE.md already prescribes for this nix-mineral host) so the tuigreet generation stays bootable. greetd restarts on failure, so a crashing greeter loops rather than dropping to a shell — plan on the previous generation, not on a rescue. Second: this module lands on deadPc automatically via desktop-all's `attrValues`, so the host's own `services.greetd` block must be removed in the same commit or evaluation fails with a conflicting definition of `default_session.command`.

```nix
{
  config,
  lib,
  pkgs,
  vars,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  # Connector names come from `noctalia-greeter outputs` / `hyprctl monitors`.
  # Pinning [output].name disables the other connectors at KMS during greet;
  # a disconnected name falls back to "show on all outputs", so this is safe.
  outputByHost = {
    deadPc = {
      name = "DP-3";      # the 240 Hz centre panel
      width = 1920;       # both required, or the override is ignored
      height = 1080;      # match the session mode => no modeset flash
    };
  };

  greeterToml = tomlFormat.generate "greeter.toml" ({
    session.default = "Hyprland";   # the Name= field, not the .desktop stem
    user.default = vars.username;

    appearance = {
      # "Synced" WITHOUT an [appearance.palette] block: a complete palette
      # here would outrank sync.toml forever and freeze the greeter while the
      # desktop regenerates its palette from every new wallpaper.
      scheme = "Synced";
      theme_mode = "dark";
      password_style = "default";
      hide_logo = true;
      corner_radius_scale = 1.0;
      font_family = config.stylix.fonts.sansSerif.name;
      power_buttons_position = "bottom-right";
      # Inert: [appearance].scheme above overrides any UI pick in sync.toml.
      scheme_selector_position = "hidden";
    };

    idle.timeout = 300;

    cursor = {
      theme = config.stylix.cursor.name;
      size = config.stylix.cursor.size;
      path = "${config.stylix.cursor.package}/share/icons";
    };

    keyboard = {
      layout = vars.keyboardLayout;
      numlock = true;
    };

    auth = {
      allow_empty_password = false;
      request_timeout = 60;
    };
  }
  // lib.optionalAttrs (outputByHost ? ${config.networking.hostName}) {
    output = outputByHost.${config.networking.hostName};
  });
in {
  # Puts noctalia-greeter, noctalia-greeter-apply-appearance and the packaged
  # polkit action on the system path -- all three are what make
  # greeter::appearanceSyncAvailable() return true in the shell.
  environment.systemPackages = [pkgs.noctalia-greeter];

  # Noctalia writes avatar_path into AccountsService IconFile so the greeter
  # can reuse it; /home/${vars.username} is 0700 so there is no other route.
  services.accounts-daemon.enable = true;

  services.greetd = {
    enable = true;
    # default_session.user is deliberately left at the nixpkgs default
    # ("greeter", a system user the greetd module creates). The tuigreet config
    # this replaces ran the greeter as the login user itself.
    settings.default_session.command = lib.getExe pkgs.noctalia-greeter;
  };

  systemd.tmpfiles.settings."10-noctalia-greeter" = {
    "/var/lib/noctalia-greeter".d = {
      user = "greeter";
      group = "greeter";
      mode = "0750";
    };
    # Same L+ (force symlink) the upstream 1.3.1 module uses: replaced on every
    # activation, while sync.toml and the synced wallpapers stay mutable
    # alongside it.
    "/var/lib/noctalia-greeter/greeter.toml"."L+" = {
      user = "greeter";
      group = "greeter";
      argument = "${greeterToml}";
    };
  };
}
```

### 3. (high) Delete the tuigreet greetd blocks from both hosts

**File:** `hosts/deadPc/config.nix`

**Rationale:** Mandatory companion to the greeter module — two normal-priority definitions of `services.greetd.settings.default_session.command` is an evaluation error, not a silent override. Also removes `user = "deadmade"`, which is the thing keeping greetd from using the `greeter` system user the nixpkgs module creates (`default_session.user = lib.mkDefault "greeter"`); today the login screen runs with your own uid before you have authenticated, and /var/cache/tuigreet is owned greeter:greeter so tuigreet's last-session cache never worked anyway. `pkgs.tuigreet` goes out of environment.systemPackages in both hosts. The identical 8-colour ANSI theme string (`border=magenta;text=cyan;...`) is what this whole change deletes: those are TTY palette indices, so the greeter's colours were a function of `vt.default_red/grn/blu` on the kernel cmdline and had no relationship to the desktop theme at all.

**Verified against:** hosts/deadPc/config.nix:95,104-114; hosts/deadConvertible/config.nix:89,103-116; nixpkgs nixos/modules/services/display-managers/greetd.nix (default_session.user = mkDefault "greeter", users.users.greeter, tmpfiles /var/cache/tuigreet)

**Risk:** deadConvertible's connector names are unknown to me, so it gets no `[output]` entry in outputByHost and the greeter will mirror on every connected output there — which is the documented default and correct for a laptop that docks. If you want it pinned, run `noctalia-greeter outputs` on that host first.

```nix
  # DELETE from hosts/deadPc/config.nix (lines ~104-114) and the equivalent
  # block in hosts/deadConvertible/config.nix (~103-116):
  #
  #   services.greetd = {
  #     enable = true;
  #     settings = {
  #       default_session = {
  #         user = "deadmade";
  #         command = "${pkgs.tuigreet}/bin/tuigreet ... --cmd Hyprland";
  #       };
  #     };
  #   };
  #
  # and drop `tuigreet` from environment.systemPackages in both hosts.
  #
  # deadConvertible additionally needs, in its imports list:
  #     outputs.nixosModules.desktop.hyprland
  #     outputs.nixosModules.desktop.greeter
  # (it cherry-picks modules instead of using nixosProfiles.desktopAll, so the
  # attrValues auto-discovery that covers deadPc does not reach it).
```

### 4. (medium) Passwordless polkit rule for greeter appearance sync

**File:** `modules/nixos/desktop/greeter.nix`

**Rationale:** Without this, `auto_sync = true` pops an administrator password prompt on every wallpaper rotation — 48 times a day at a 1800 s interval. This is the piece that makes the greeter actually track the desktop. It works, and I traced exactly why: greeter 1.3.1 predates the 1.5.0 constrained/passwordless protocol, so Noctalia takes the LegacyAuthenticated path, which calls `<escalator> <helper> <staging-dir>`. `findApplyHelper()` resolves the helper through `canonicalExecutablePath()` — `std::filesystem::canonical`, which follows /run/current-system/sw/bin's symlink down to the /nix/store path — and that is precisely the path meson substituted into `@bindir@` for the policy's `org.freedesktop.policykit.exec.path` annotation, so pkexec selects this action rather than the generic `org.freedesktop.policykit.exec`. `isTrustedPrivilegeExecutable()` also passes: it requires uid-0, non-group/other-writable regular file with an all-root, non-other-writable-unless-sticky parent chain, and /nix/store is `drwxrwxr-t root nixbld 1775` (sticky bit set) under `drwxr-xr-x root /nix` and `/`. The rule is narrow: one action id, one user, local + active session only.

**Verified against:** src/shell/greeter/greeter_appearance_sync.cpp:105-112 (canonicalExecutablePath), :314-322 (isTrustedPrivilegeExecutable), :861-871 (findApplyHelper), :906-925 (legacy escalator path); src/core/process/process.cpp:745-753 (resolvePrivilegeEscalator prefers run0); noctalia-greeter data/org.noctalia.greeter.apply-appearance.policy.in + meson.build:259-262 (@bindir@ = prefix/bindir); stat of / /nix /nix/store; ls -la /run/current-system/sw/bin/{run0,pkexec}

**Risk:** This grants ${vars.username} a permanent passwordless root-executed command. The helper validates its own caller and its constrained mode only ever targets /var/lib/noctalia-greeter, but it is still a standing privilege on a nix-mineral-hardened host. If that trade is unwanted, drop this rule AND set `auto_sync = false`; the greeter still gets its palette from a manual Settings -> Security -> Sync Now (or `noctalia msg greeter-sync`), which prompts once. Do not leave auto_sync on without the rule. Also unverified: whether polkitd resolves the annotated exec path identically for a symlink-invoked pkexec if Noctalia's canonicalisation is ever bypassed — if the prompt still appears, `journalctl -u polkit` names the action that was actually requested.

```nix
  # Noctalia's legacy greeter sync runs `<escalator> <apply-helper> <staging>`.
  # findApplyHelper() canonicalises the helper through the
  # /run/current-system/sw/bin symlink to its /nix/store path -- which is
  # exactly the path meson baked into the packaged policy's
  # org.freedesktop.policykit.exec.path annotation -- so pkexec picks this
  # action instead of the generic org.freedesktop.policykit.exec, and this rule
  # applies. Requires shell.greeter_sync.privilege_command = "pkexec" on the
  # Home Manager side (see the next change): resolvePrivilegeEscalator()
  # otherwise prefers run0, which authenticates against
  # org.freedesktop.systemd1.manage-units and cannot be narrowed to one helper.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.noctalia.greeter.apply-appearance"
          && subject.user == "${vars.username}"
          && subject.local
          && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
```

### 5. (medium) Turn on greeter sync from the shell, forced through pkexec

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `privilege_command = "pkexec"` is not cosmetic — it is required for the polkit rule above to ever be consulted. `process::resolvePrivilegeEscalator()` checks `run0` first and only falls back to `pkexec`, and `/run/current-system/sw/bin/run0` exists on this box (systemd 260.2). run0 authenticates against `org.freedesktop.systemd1.manage-units`, which you cannot scope to one helper without handing over broad systemd control, so the default path would prompt forever. With the override, `buildPrivilegedApplyCommand` emits `pkexec '<store-path-helper>' '<staging-dir>'` (no state-env prefix, because the default /var/lib/noctalia-greeter state dir makes `legacyStateEnvironment` return nullopt). `auto_sync` then fires on a 1 s debounce whenever wallpaper, colours, theme mode or shell font change, and Sync also copies the live monitor layout, transforms and scales into the greeter's sync.toml — which is how the greeter stays correct on three monitors without any of that being hand-written.

**Verified against:** src/core/process/process.cpp:745-753; src/shell/greeter/greeter_appearance_sync.cpp:834-841, 853, 878-896, 952-957 (appearanceSyncAvailable); src/app/application_ui.cpp:308-315 (scheduleGreeterAutoSync, 1000 ms debounce); docs/user/configuration/shell.mdx:551-623 (greeter_sync table)

**Risk:** Each sync copies the current wallpaper (2-8 MB from wallpapers/) into /var/lib/noctalia-greeter; at 1800 s rotation that is ~48 writes/day to the root filesystem. Sync is single-flight (an overlapping request is reported busy, not queued), and a legacy sync that finds no session able to host a polkit prompt returns StagedOnly rather than hanging. If the greeter package is ever absent, `appearanceSyncAvailable()` returns false and auto_sync is silently ignored — no error, so verify with `noctalia msg greeter-sync` once after the first reboot.

```nix
      shell = {
        # ... existing shell settings ...

        greeter_sync = {
          # Push wallpaper + palette + monitor layout to /var/lib/noctalia-greeter
          # whenever the wallpaper rotates or the palette regenerates.
          auto_sync = true;

          # MUST be set. resolvePrivilegeEscalator() prefers run0 (present here:
          # /run/current-system/sw/bin/run0), and run0 authenticates against
          # org.freedesktop.systemd1.manage-units, which the narrow polkit rule
          # in modules/nixos/desktop/greeter.nix cannot cover. Forcing pkexec
          # makes the packaged org.noctalia.greeter.apply-appearance action the
          # one that gets evaluated.
          privilege_command = "pkexec";
        };
      };
```

### 6. (high) Configure the lock screen: desktop capture, blur, tint, kill the inert fingerprint path

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `blurred_desktop = true` is the premium move and it does what it sounds like — the docs are explicit: "Capture each output before lock and use it as the lock screen background", the snapshot lives in memory only until unlock, and a failed capture falls back to the per-output wallpaper. Cost on 3x1080p is three RGBA frames, ~8.3 MB each, ~25 MB resident while locked plus one blur pass on an RTX 3070 — nothing. But the default blur/tint were tuned for a wallpaper, not a live desktop: at `blur_intensity = 0.5` and 1080p, large text (terminal titles, browser headings) is still legible through the blur, which is a genuine shoulder-surfing leak on a screen you walk away from. 0.75 destroys glyph structure while still preserving the composition and colour of what was on screen — 1.0 flattens it to a colour field and throws away the "this is my desktop, softened" effect that is the whole point. `tint_intensity` 0.3 -> 0.45 pushes the background toward the `surface` colour far enough that the login box has contrast against a bright wallpaper capture; 0.45 is the point where the box reads cleanly without the background going opaque. `wallpaper = ""` stays empty deliberately (docs: ignored while capture is active, and otherwise each output uses its own desktop wallpaper — correct with rotation). `monitors = []` stays empty deliberately: listing only DP-3 would leave the other two outputs BLACK, not unlocked-looking. `fingerprint = false` on a machine with no fprintd device — it is currently offering a PAM path that can never succeed.

**Verified against:** `noctalia config export full` lines 247-256 (the section is [lockscreen], not [lock_screen]); docs/user/configuration/shell.mdx:401-425

**Risk:** `blurred_desktop` needs a working screencopy path in the compositor. Hyprland provides it, but if capture fails you silently get the plain wallpaper instead — check for a lock-screen background that does not match what was on screen. On NVIDIA the capture happens at lock time on three outputs at once, so a brief hitch on locking is possible; if it is objectionable, blurred_desktop = false plus the same blur/tint values still gives a good wallpaper-based lock screen.

```nix
      lockscreen = {
        # Snapshot each output before locking and blur that, instead of showing
        # the flat wallpaper. Costs ~25 MB resident on 3x1080p, in memory only
        # until unlock; a failed capture falls back to the wallpaper.
        blurred_desktop = true;

        # 0.5 (default) still leaves large on-screen text legible at 1080p.
        # 0.75 destroys glyph structure but keeps the composition readable as
        # "your desktop"; 1.0 flattens it to a colour field.
        blur_intensity = 0.75;

        # 0.3 leaves the login box low-contrast over a bright capture. 0.45 is
        # where the surface tint carries the box without going opaque.
        tint_intensity = 0.45;

        # No fprintd device on this host: the default true offers a PAM path
        # that can never succeed.
        fingerprint = false;

        # Deliberately NOT set:
        #   wallpaper = ""  -> ignored under capture, and otherwise correctly
        #                      follows each output's rotating wallpaper.
        #   monitors  = []  -> listing connectors leaves the others BLACK.
        #   lock_before_suspend = true (default) is already what we want.
      };
```

### 7. (high) Make the machine actually lock when idle

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** All three idle behaviours are `enabled = false` today, so deadPc never locks, never blanks and never suspends — the lock screen you just configured would only ever be reached by SUPER+L. Timeouts are absolute idle seconds (the upstream example uses lock=600, screen-off=660, suspend=900), so they are ordered, not cumulative. lock at 600 s is the standard "stepped away" threshold. screen-off at 900 s rather than the doc's 660: on a desk with three panels you frequently read something for several minutes without touching input, and `screen_off` blanking mid-read is far more annoying than the lock (which is invisible until you return); 300 s after the lock is enough separation to never fire while you are actually present. `lock-and-suspend` stays OFF: this host does binfmt-emulated aarch64/riscv64 builds and cross-compilation, and suspending a workstation mid-build is a real loss — suspend stays a deliberate SUPER+SHIFT+L / session-menu action. `pre_action_fade_seconds` is already 2.0 by default and gives the click-through dim-then-lock fade, so it is not restated.

**Verified against:** `noctalia config export full` lines 199-224; docs/user/services/idle.mdx:10-60

**Risk:** The 2 s fade overlay is a layer-shell overlay covering the full monitor including the bar; it is click-through and cancels on activity, so it should never trap input, but it is the one new full-screen surface being introduced. With blurred_desktop on, the idle lock capture happens right at the end of that fade — confirm the captured frame is the desktop and not the dim overlay after the first real idle lock.

```nix
      idle = {
        # Absolute idle seconds, not cumulative (see the upstream example:
        # lock=600, screen-off=660, suspend=900).
        behavior = {
          lock = {
            enabled = true;
            timeout = 600;   # 10 min: standard "stepped away" threshold
          };
          "screen-off" = {
            enabled = true;
            timeout = 900;   # 5 min after the lock; blanking mid-read on a
                             # 3-monitor desk is worse than locking, which is
                             # invisible until you come back
          };
          "lock-and-suspend".enabled = false;
            # Stays off: this host runs binfmt-emulated aarch64/riscv64 builds.
            # Suspend remains an explicit action (SUPER+SHIFT+L / session menu).
        };
        # pre_action_fade_seconds is already 2.0 and gives the click-through
        # dim-then-act fade; left at the default.
      };
```

### 8. (medium) Session panel: 3x2 grid, six actions, countdowns on the destructive two

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Grid is the better look, but with the stock FIVE actions `grid_columns = 3` gives a ragged 3+2 and `grid_columns = 2` gives 2+2+1 — neither reads as designed. That is the actual argument for a sixth entry, not decoration: six actions at 3 columns is a clean 3x2, and row-major fill lets the top row be "stay logged in" (lock / lock & suspend / screens off) and the bottom row "leave" (log out / reboot / shut down). The sixth is a `command` entry running `noctalia msg dpms-off`, which is genuinely useful on a three-panel desk and is a documented IPC command. Glyphs: the defaults resolve through the alias table to lock->lock, logout->logout, lock_and_suspend->suspend->player-pause, reboot->refresh, shutdown->power — so lock_and_suspend and a plain suspend would share the same glyph. Overriding lock_and_suspend to `zzz` (a real Tabler name, confirmed present in assets/fonts/tabler.json) is the one glyph that needs stating; `moon` for the custom screens-off entry likewise. Labels stay unset so the translated defaults are used — only the custom entry needs one. `countdown_seconds = 5` on reboot and shutdown only: long enough to read the badge and hit Escape, short enough not to feel like a nag, and it matches the docs' own example; lock/logout/suspend get 0 because they are recoverable. `variant = "destructive"` on reboot as well as shutdown (only shutdown has it today) — both discard unsaved work. Shortcuts 1-6 with `show_shortcuts = true` (already the default) make the whole panel keyboard-drivable.

**Verified against:** docs/user/configuration/shell.mdx:487-549 (fields, enums, variant list, the [[shell.session.actions]] example); src/shell/session/session_action_meta.cpp:9-70 (valid actions + defaultGlyph); src/render/text/glyph_registry.cpp:78-82 (shutdown->power, reboot->refresh, suspend->player-pause); python check of assets/fonts/tabler.json for zzz/moon/lock/logout/power/refresh; `noctalia msg --help` (dpms-off)

**Risk:** Declaring `actions` replaces the built-in five wholesale — anything omitted disappears from the panel, the launcher's /session provider, and `noctalia msg session <action>`. A plain `suspend` (no lock) is intentionally absent. `session_placement` stays at its "attached" default, which anchors the panel to the bar's inward edge; that is right for the full-width-bar chrome decision, and since the panel is opened by IPC with only one bar defined, the "first enabled bar on the output" resolution is unambiguous — but if a second bar is ever added, `shell.panel_anchor_bar` will need setting.

```nix
      shell.session = {
        # Five actions at 3 columns is a ragged 3+2; a sixth makes it 3x2, with
        # row 1 = "stay logged in" and row 2 = "leave".
        grid = true;
        grid_columns = 3;

        actions = [
          {
            action = "lock";
            shortcut = "1";
          }
          {
            action = "lock_and_suspend";
            # Default glyph resolves to "suspend" -> player-pause, the same as a
            # plain suspend entry. zzz differentiates it.
            glyph = "zzz";
            shortcut = "2";
          }
          {
            action = "command";
            label = "Screens off";
            glyph = "moon";
            command = "noctalia msg dpms-off";
            shortcut = "3";
          }
          {
            action = "logout";
            shortcut = "4";
          }
          {
            action = "reboot";
            # Discards unsaved work exactly like shutdown does.
            variant = "destructive";
            countdown_seconds = 5;
            shortcut = "5";
          }
          {
            action = "shutdown";
            variant = "destructive";
            countdown_seconds = 5;
            shortcut = "6";
          }
        ];
      };
```

### 9. (medium) Bind the session panel and stop pretending SUPER+E works

**File:** `modules/home-manager/windowManager/hyprland/config.nix`

**Rationale:** Nothing currently opens the session panel — it is reachable only by clicking the bar's session widget. `panel-toggle session` is the documented IPC id. SUPER+SHIFT+E ("Exit") is free: SUPER+E alone is the file-manager bind and SHIFT+E is unused across the whole bind table. I deliberately avoided SUPER+Escape despite it being the conventional choice, because I could not verify the exact key name the Lua `hl.bind` parser wants for Escape and a silently-dead bind is worse than a slightly odd mnemonic. This sits next to the existing SUPER+L / SUPER+SHIFT+L locks, which already use the correct `noctalia msg session lock` / `lock-and-suspend` spellings (canonicalActionName maps the hyphenated IPC form to lock_and_suspend).

**Verified against:** docs/user/ipc/surfaces.mdx:32 (panel-toggle session); `noctalia msg --help` (panel-toggle <id>); modules/home-manager/windowManager/hyprland/config.nix bind table; src/shell/session/session_action_meta.cpp:70-78 (canonicalActionName)

**Risk:** None to the session itself. Separately worth knowing (not fixed here): `fileManager._var = "thunar"` binds SUPER+E to a package that is not installed on this host — nautilus is. That is a one-word change but belongs with the packages cleanup, not with this domain.

```nix
      -- Session / power menu. `panel-toggle session` is the documented IPC id;
      -- SUPER+SHIFT+E ("Exit") -- SUPER+E alone is the file manager bind.
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))
```

### 10. (medium) Compose the startup: no wizard, fade the first wallpaper in, autostart after the shell is up

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** Three separate causes of the abrupt feel. (1) `setup_wizard_enabled = true` means Noctalia will auto-open its first-run wizard on any machine where `.setup-complete` is missing — the docs name exactly this case: "Use this for declarative or preseeded deployments". On a config that is fully declared in Nix the wizard can only produce state-file drift; turn it off. (2) `transition_on_startup = false` means the first wallpaper snaps in with no transition — flipping it to true fades (or wipes) in from black at shell startup, which is the single cheapest "composed" win available and costs one 1500 ms animation once per login. (3) librewolf is exec'd from `hyprland.start`, i.e. the instant the compositor is up, which races Noctalia's bar for the layer-shell exclusive zone — the window can map, get laid out, and then be shoved down when the bar finally reserves its strip. Moving it to Noctalia's `started` hook (documented as firing "once after Noctalia finishes startup (IPC ready)") guarantees the shell owns its space before the first window appears. Hooks are shell command strings or ordered arrays, so this generalises if more autostarts are added later.

**Verified against:** docs/user/configuration/shell.mdx:196 (setup_wizard_enabled); docs/user/desktop/wallpaper.mdx:18,78 (transition_on_startup); docs/user/automation/hooks.mdx:9-20 (hooks are shell command strings/arrays; `started` fires once after IPC ready); /nix/store/...hyprland-0.56.2/share/hypr/stubs/hl.meta.lua:830,862 and share/hypr/hyprland.lua:315-355

**Risk:** If noctalia.service fails to start, autostart is lost along with it — an acceptable trade, since a session with no bar is already broken. Placing librewolf on a specific workspace/monitor is the one thing I could NOT verify: the shipped Lua stub declares `hl.exec_cmd(cmd, rules?: table<string, string|number|boolean>)` and `hl.window_rule({ name, match = { class = ... }, ... })`, but neither the stub nor the shipped hyprland.lua example shows the rule-key vocabulary for a workspace assignment, and hyprsplit remaps workspace ids per monitor on top of that. Treat placement as a separate, experimentally-verified step rather than something to write blind. Also flagging an overlap: trimming `wallpaper.transition = ["fade" "wipe"]` (from the six-effect default pool) would stop honeycomb/stripes from firing as a login transition, but it also changes every 30-minute rotation, so that call belongs to whoever owns the wallpaper/animation domain.

```nix
      shell = {
        # ... existing shell settings ...

        # Everything here is declared in Nix; the first-run wizard can only
        # create state-file drift. The docs name declarative deployments as
        # exactly this option's use case.
        setup_wizard_enabled = false;
      };

      wallpaper = {
        # ... existing wallpaper settings ...

        # Fade the first wallpaper in from black at shell startup instead of
        # snapping it in. One 1500 ms animation per login.
        transition_on_startup = true;
      };

      # Autostart AFTER the shell is up and IPC is ready, so windows never map
      # before Noctalia has reserved the bar's exclusive zone. Replaces the
      # hl.exec_cmd("librewolf") inside hl.on("hyprland.start", ...) in
      # modules/home-manager/windowManager/hyprland/config.nix -- delete it
      # there in the same change, or librewolf launches twice.
      hooks.started = ["librewolf"];
```

### 11. (low) Fix the broken avatar (currently a dangling path shown on the lock screen)

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** `avatar_path = "/home/deadmade/.face"` points at a file that does not exist (confirmed), while `modules/home-manager/assets/avatar.jpg` sits unused in the repo. Pointing the option at the Nix path makes it a world-readable /nix/store path, which matters for more than tidiness: the greeter runs as the `greeter` user and /home/deadmade is 0700, so a ~/.face would be unreadable to it even if it existed. Noctalia mirrors avatar_path into AccountsService IconFile (which is why services.accounts-daemon.enable is turned on in the greeter module), and AccountsService can only copy a file it can actually read.

**Verified against:** ls ~/.face -> ENOENT; find of modules/home-manager/assets/avatar.jpg; stat /home/deadmade -> drwx------; docs/user/configuration/shell.mdx:188 (avatar_path / AccountsService IconFile)

**Risk:** The relative path is written from modules/home-manager/windowManager/hyprland/noctalia.nix to modules/home-manager/assets/avatar.jpg — check the ../ depth against the actual file when applying (the file is three directories up from noctalia.nix, i.e. ../../assets/ relative to windowManager/hyprland/). Wrong depth is an eval error, not a silent miss.

```nix
      shell = {
        # Was "/home/${vars.username}/.face", which does not exist. A store path
        # is world-readable, which matters because Noctalia mirrors this into
        # AccountsService IconFile for the greeter, and /home/${vars.username}
        # is mode 0700.
        avatar_path = "${../../assets/avatar.jpg}";
      };
```

### 12. (medium) Resolve the stale lockscreen login-box state (the login box is NOT gated by lockscreen_widgets.enabled)

**File:** `modules/home-manager/windowManager/hyprland/noctalia.nix`

**Rationale:** This is the item that needed care, and the answer is counter-intuitive. `LockSurface::isLoginBoxEnabled()` and `LockSurface::resolveLoginStyle()` both call `lockscreen_login_box::findForOutput(config().lockscreenWidgets.widgets, m_outputKey)` with NO check of `lockscreenWidgets.enabled`, returning `true` / a default style when no entry exists. So: the login box always renders on every output, and `lockscreen_widgets.enabled = false` gates only the extra-widgets host and its editor — which means the three stale `lockscreen-login-box@DP-2/DP-3/HDMI-A-1` entries sitting in ~/.local/state/noctalia/settings.toml ARE live right now, setting cx/cy/box_width/opacity per monitor. Leave `enabled = false` (the user declined desktop widgets; this is a different system, but adding widgets is still not wanted) and declare the three login boxes instead. cy 961 -> 500: 961 puts the box near the bottom edge; at 1080 px with a 196 px panel, centre 500 leaves 402 above and 482 below — the ~55/45 split that reads as optically centred and clears the lower third where wallpaper subjects usually sit. background_opacity 0.88 -> 0.72 because blurred_desktop plus tint 0.45 already mutes the background, so 0.88 makes the card a solid slab; 0.72 keeps the glass consistent with the translucent-bar decision. radii 12->16 and 6->10 scale with the panel. show_weather false since weather.enabled is false anyway (dead UI). All three stay enabled — disabling the flanking two would look cleaner but risks having no password field if DP-3 is ever off.

**Verified against:** src/shell/lockscreen/lock_surface.cpp:965-980 (findForOutput ignores .enabled; default panelY = sh - panelHeight - 84), :1573-1595 (resolveLoginStyle / isLoginBoxEnabled); src/shell/lockscreen/lockscreen_widgets_controller.cpp:204-209; `noctalia config export full` lines 258-295; docs/user/configuration/index.mdx:95-110 (settings.toml loads last and wins)

**Risk:** CRITICAL ordering issue: ~/.local/state/noctalia/settings.toml loads AFTER config.toml and wins, so this Nix block does nothing until the stale [lockscreen_widgets] tables are removed from that file once by hand (stop noctalia.service, delete the [lockscreen_widgets] table and its [lockscreen_widgets.widget."..."] / .settings subtables, start it). There is no IPC to do it surgically. After that, note one re-drift path: lockscreen_widgets_controller.cpp:204-209 flips `enabled` to true and writes it back to state if the lockscreen widgets EDITOR is ever opened -- so avoid `noctalia msg lockscreen-widgets-edit`. If this whole item feels like more machinery than it is worth, skipping it is defensible: the previous change (blur/tint/capture) delivers most of the visual gain, and the stale geometry is close to the built-in default anyway.

```nix
      lockscreen_widgets = {
        # Stays false: this gates the extra-widget host and its editor only.
        # The login box is rendered regardless (lock_surface.cpp:969, 1578-1595
        # read .widgets without consulting .enabled), which is why the three
        # entries below are worth declaring.
        enabled = false;
        schema_version = 2;
        widget_order = [
          "lockscreen-login-box@DP-3"
          "lockscreen-login-box@DP-2"
          "lockscreen-login-box@HDMI-A-1"
        ];

        # Identical on all three outputs. cx/cy are per-output local coords.
        widget = builtins.listToAttrs (map (out:
          {
            name = "lockscreen-login-box@${out}";
            value = {
              type = "login_box";
              output = out;
              enabled = true;      # all three: DP-3 could be powered off
              cx = 960.0;          # centre of a 1920-wide output
              cy = 500.0;          # optically centred (was 961 = near-bottom)
              box_width = 720.0;
              box_height = 196.0;
              placement_width = 1920.0;
              placement_height = 1080.0;
              rotation = 0.0;
              settings = {
                layout = "regular";
                background_color = "surface_variant";
                background_opacity = 0.72;   # was 0.88; blur+tint already mute
                background_radius = 16.0;    # was 12
                input_opacity = 1.0;
                input_radius = 10.0;         # was 6
                center_password_text = false;
                show_caps_lock = true;
                show_keyboard_layout = true;
                show_login_button = true;
                show_media = true;
                show_session_buttons = true;
                show_unlock_hint = true;
                show_weather = false;        # weather.enabled = false
              };
            };
          }) ["DP-2" "DP-3" "HDMI-A-1"]);
      };
```

### 13. (low) GRUB: leave stylix.targets.grub.enable = false (no change)

**File:** `modules/nixos/core/grub2-bootloader.nix`

**Rationale:** Recommending against, with a concrete reason rather than a shrug. The Stylix GRUB target does three things: `backgroundColor = base00`, a 1x1 `splashImage` pixel of base00, and `boot.loader.grub.font` set to a PFF2 generated by `grub-mkfont ... --size ${fonts.sizes.applications}` (12 by default). That last one is a regression, not a theme: the module's deliberate `fontSize = 48` only takes effect while `font` is left at its default, so enabling the Stylix target silently swaps a 48 pt menu for a ~12 pt one on a 1080p panel. It would also re-freeze the boot menu to Catppuccin at exactly the moment the rest of the desktop stops being Catppuccin, which is the mismatch this whole effort removes. And it is the least-seen surface on a machine that CLAUDE.md says should be updated with `nixos-rebuild boot` — you see GRUB seconds before a greeter that is about to be genuinely themed. If the budget must be spent on the pre-login surface, spend it on Plymouth instead: `quiet loglevel=0` is already on the kernel cmdline, Stylix has a `plymouth` target, and greetd has `greeterManagesPlymouth` for a smooth handoff — but that is optional and independently risky.

**Verified against:** modules/nixos/core/grub2-bootloader.nix (fontSize = 48, extraEntries); modules/nixos/desktop/stylix.nix (targets.grub.enable = false); stylix source .direnv/flake-inputs/95awhm3a9mclvmv956gfdgk4r7z9w88s-source/modules/grub/nixos.nix (mkGrubFont / backgroundColor / splashImage); /proc/cmdline (quiet loglevel=0)

**Risk:** None -- this is a decision to change nothing. The Plymouth alternative is NOT recommended for this change set: plymouth in the initrd on NVIDIA proprietary plus a nix-mineral-hardened boot is a known-fiddly combination, and it should not be stacked on top of a greeter migration that already needs a reboot to validate.

```nix
  # No change. Keeping stylix.targets.grub.enable = false (set in
  # modules/nixos/desktop/stylix.nix) is the right call:
  #
  #   - The Stylix GRUB target sets boot.loader.grub.font to a PFF2 built at
  #     stylix.fonts.sizes.applications (~12). NixOS only honours
  #     boot.loader.grub.fontSize while `font` is at its default, so enabling
  #     it would silently drop this module's fontSize = 48 to ~12 on 1080p.
  #   - It only paints backgroundColor + a 1x1 splash pixel: not a theme.
  #   - It re-pins the boot menu to Catppuccin while the desktop moves to a
  #     wallpaper-derived palette.
  #
  # If a themed pre-login surface is wanted, Plymouth is the place to spend it
  # (quiet + loglevel=0 are already on the cmdline; Stylix has a plymouth
  # target; greetd has greeterManagesPlymouth for the handoff).
```

### 14. (low) Session plumbing: nothing is broken today -- here is the evidence

**File:** `modules/home-manager/windowManager/hyprland/default.nix`

**Rationale:** Answering the question as asked rather than recommending change for its own sake. The session is healthy: `loginctl list-sessions` shows session 3 on seat0 with Class=user, Type=wayland, Desktop=hyprland, Active=yes; `graphical-session.target`, `hyprland-session.target` and `noctalia.service` are all active; both xdg-desktop-portal and xdg-desktop-portal-hyprland are running; XDG_CURRENT_DESKTOP=Hyprland, XDG_SESSION_TYPE=wayland, XDG_RUNTIME_DIR=/run/user/1000. The chain works because HM's module writes `systemctl --user stop/start hyprland-session.target` into the generated config, and that target declares `BindsTo = graphical-session.target` -- BindsTo implies Requires, so starting it pulls graphical-session.target up, which is what noctalia.service is WantedBy. Nothing to fix. What IS genuinely missing is covered by the first change: no wayland-sessions entry (which blocks the greeter) and no cap_sys_nice wrapper (which costs the 240 Hz panel some frame-pacing headroom). PAM is already correct -- the nixpkgs greetd module sets `security.pam.services.greetd.startSession = true`, which puts pam_systemd in the session stack; that is precisely what noctalia-greeter's own setup_greetd_pam.sh patches in by hand on other distros, and it is what gives the greeter its logind session and seat0/DRM-master access.

**Verified against:** loginctl list-sessions / show-session; systemctl --user is-active; ps of PID 4439 (~/.nix-profile/bin/Hyprland) and 4365 (store start-hyprland); HM source /nix/store/v573js9566ja0r1r1s8pw6y06z2wq5k4-source/modules/services/window-managers/hyprland.nix:27-29,183-184,513-514,653-664; nixpkgs greetd.nix (pam startSession); noctalia-greeter-1.3.1/scripts/setup_greetd_pam.sh

**Risk:** One live-fire consequence of the greeter migration to be aware of: today greetd runs `--cmd Hyprland`, which resolves through the login shell to ~/.nix-profile/bin/Hyprland (confirmed by the running process). Once programs.hyprland is enabled, /run/wrappers/bin/Hyprland exists and comes first on PATH, and the greeter launches the session via the .desktop Exec (/nix/store/...-hyprland-0.56.2/bin/start-hyprland) instead. Both point at 0.56.2 once the package is pinned to unstable -- that pin is what makes this safe. Also note hyprland-uwsm.desktop will appear in the greeter's picker as "Hyprland (uwsm-managed)"; picking it by accident gives a half-managed session, which is why [session].default is pinned to the exact string "Hyprland".

```nix
  # No change needed here. For the record, verified on the live session:
  #
  #   loginctl        -> session 3, seat0, Class=user, Type=wayland,
  #                      Desktop=hyprland, Active=yes
  #   systemctl --user is-active graphical-session.target hyprland-session.target
  #                      noctalia.service  -> active / active / active
  #   xdg-desktop-portal + -hyprland       -> both running
  #   XDG_CURRENT_DESKTOP=Hyprland  XDG_SESSION_TYPE=wayland
  #
  # The chain: HM's systemd.enable writes
  #   exec-once = dbus-update-activation-environment --systemd ... \
  #               && systemctl --user stop/start hyprland-session.target
  # and hyprland-session.target has BindsTo = graphical-session.target
  # (BindsTo implies Requires), which pulls graphical-session.target up ->
  # noctalia.service (WantedBy that target) starts. Already correct.
  #
  # PAM is also already handled: the nixpkgs greetd module sets
  # security.pam.services.greetd.startSession = true, i.e. pam_systemd in the
  # session stack -- exactly what noctalia-greeter's setup_greetd_pam.sh adds
  # by hand elsewhere, and what gives its compositor a logind session on seat0.
```

## Open questions

1) NVIDIA + wlroots 0.20: noctalia-greeter runs its own bundled compositor and is the first thing on this box to modeset before login (tuigreet never touched the GPU). modesetting.enable=true and /dev/dri/card1 exist, but this is unverifiable without rebooting — do the switch with `nixos-rebuild boot` and keep the tuigreet generation. If it fails, the fallback is NOT ReGreet: Stylix's regreet target themes via GTK/adw-gtk3 from the base16 scheme, i.e. it would be Catppuccin-frozen while the desktop is wallpaper-derived — precisely the mismatch being removed. ReGreet is only worth it if the wlroots greeter genuinely cannot drive this GPU.
2) Passwordless polkit: do you accept a standing `polkit.Result.YES` for one action id for your user on a nix-mineral host? If not, set auto_sync=false and sync manually — but do not leave auto_sync on without the rule (admin prompt every 30 minutes).
3) Greeter version: nixpkgs has 1.3.1; passwordless/constrained sync needs 1.5.0+, and `programs.noctalia-greeter.passwordless-sync-users` does not exist in 1.3.1's module. If 1.5.0 lands in nixpkgs later, the hand-written polkit rule should be replaced by the packaged one.
4) deadConvertible connector names are unknown to me — run `noctalia-greeter outputs` there before adding an outputByHost entry; it currently gets the mirror-on-all-outputs default.
5) Autostart placement (librewolf on a specific workspace/monitor) is unverified: `hl.exec_cmd(cmd, rules?)` exists in the 0.56.2 Lua stub but neither the stub nor the shipped example documents the rule-key vocabulary, and hyprsplit remaps workspace ids per monitor. Needs experimental confirmation, not a blind write.
6) Overlap with the wallpaper/animation domain: `wallpaper.transition = ["fade" "wipe"]` (trimming the six-effect pool so honeycomb/stripes never fire as a login transition) also changes every rotation — that call is not mine.
7) The lockscreen_widgets change is inert until the stale [lockscreen_widgets] block is removed from ~/.local/state/noctalia/settings.toml by hand; if you would rather not touch state, drop that change and keep the blur/tint/capture one, which carries most of the visual gain.
8) Out of scope but adjacent, flagged not fixed: `fileManager._var = "thunar"` binds SUPER+E to an uninstalled package (nautilus is the one present).
