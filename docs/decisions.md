# Decisions

Durable why for settings that look optional, wrong, or tempting to "fix". File paths are where the setting lives.

## Desktop

Files: `flake/lib/theme.nix`, `modules/nixos/desktop/stylix.nix`, `modules/home-manager/core/stylix.nix`, `modules/home-manager/desktop/{gtk,qt}.nix`, `modules/home-manager/windowManager/hyprland/noctalia.nix`

Noctalia owns the desktop background and the runtime palette (`theme.source = "wallpaper"`, `wallpaper_scheme = "vibrant"`). Mode is `dark`, not `auto` — auto would rewrite templated app configs twice a day.

Stylix `image` is **not** the wallpaper. mpvpaper draws a video. The image is still set because `stylix/palette.nix` throws if both `image` and `base16Scheme` are null. Do not enable Stylix hyprland/hyprpaper/grub wallpaper targets; hyprpaper was painting a second layer under Noctalia.

`base16Scheme` is Catppuccin Mocha, for the handful of apps Noctalia cannot template. Wallpaper-derived base16 was tried: Stylix assigns dominant colours without regard to slot meaning, so git diff +/- and error/success text collapse. Fonts and cursor stay Stylix's job. Both NixOS and Home Manager stylix modules import `flake/lib/theme.nix` so they cannot drift. Do not wrap the NixOS stylix attrset in a blanket `lib.mkDefault` — a host setting `stylix.<anything>` would then replace the whole set.

Stylix gtk/qt/bat/tmux/zed/fzf/starship targets are off. Those files are either rewritten by Noctalia `apply.sh` (EACCES on a store symlink) or already themed elsewhere. GTK theme name, icons, and fonts live in `desktop/gtk.nix` (`adw-gtk3-dark`, `gtk4.theme = null` so HM does not write `gtk.css`). Qt: Noctalia's qt template writes only a palette file; `desktop/qt.nix` points qt5ct/qt6ct at it. Builtin starship id is not used — its `apply.sh` cats onto a store symlink. A user template renders the palette into a path we choose; layout stays in `terminal/starship/starship.toml`. Tmux: `source-file -q "$HOME/.config/tmux/themes/noctalia.conf"` must be byte-exact and the last line of `extraConfig`, or Noctalia's apply.sh dies EACCES rewriting the store symlink.

Enabled Noctalia builtin templates: hyprland, gtk3, gtk4, qt, ghostty, btop. Community: zed, tmux, fzf, bat, discord. Not neovim (external nvim flake never loads the generated file), not vscode (extension not installed). Discord needs the "noctalia" theme ticked once in Vesktop.

Cursor size is 24 — Bibata does not ship 25. Sans is Adwaita Sans, not Montserrat.

## Noctalia plugins

File: `modules/home-manager/windowManager/hyprland/noctalia.nix`, packages in `modules/home-manager/windowManager/hyprland/default.nix`

Plugins are pinned `path` sources (`auto_update = "none"`). Built-in `community` / `official` git sources are disabled so nothing is fetched at startup.

Enabled: `kenn/keybind-cheatsheet`, `dunarand/tmux-provider`, `noctalia/mpvpaper`, `jamesfeeder/special-workspaces`, `cleboost/zed-provider`, `nilsonlinux/rss-notifier`, `felipeartur/ai-usagebar`.

Rejected:

- `jrohland/claudecode` — collector is ~15s on this account; `noctalia.runAsync` defaults to 5s, so it always times out and auto-disables after 3 failures. Use ai-usagebar instead.
- `k4n4t4/hypr-submap` — callback type mismatch (`trim` got a table).
- `cleboost/ssh-launcher` — no `~/.ssh/config`; Pi/server go through deploy-rs.

mpvpaper needs `mpvpaper`, `mpv`, `socat`, and **`ffmpeg-headless`** (undeclared in the plugin; without it the still that feeds the palette is never written). Assignments and the picker thumbnail are runtime state: seed writable files when absent (`home.activation.noctaliaMpvpaper*`). Do not `home.file` them — the plugin rewrites them. Palette hangs off `~/.cache/noctalia/mpvpaper/<mangled-video-path>.jpg`; the still is committed under `modules/home-manager/assets/`. Pause/resume mpvpaper on lock via hooks (`plugin … all pause` with empty payload). `ai-usagebar` must be on PATH by name. zed-provider needs the sqlite3 CLI. Pin the usage widget to `vendor = "anthropic"` — `auto` surfaces error tiles for unconfigured providers.

Do not import Noctalia's NixOS module for `recommendedServices`. It would define a second systemd user service for the shell. Enable `upower` and `power-profiles-daemon` on the host instead.

Lockscreen widgets must be a fixed point of Noctalia's `normalizeSnapshot` or `~/.local/state/noctalia/settings.toml` shadows this config on every start: a `login_box` for every output, explicit `placement_width`/`height`, `login_box.box_height = 70` (compact). Never open the lockscreen widgets editor. Do not put `button` widgets on the lock screen — they receive pointer events while locked. `idle.behavior.<name>` tables replace the builtin entry; always set `action` explicitly. Do not set `behavior_order` in the module (lists concatenate with the host).

RSS feeds: use `https://tldr.tech/api/rss/dev`, not `/webdev` (308, and noctalia.http does not follow redirects).

Wallpaper `default.path` is required when automation is off, or there is no wallpaper at startup. Picker choice in state still wins. Transitions: `["fade"]` only — random honeycomb/stripes fight the monitor zoom-out.

`colors_changed` must use `hyprctl eval '_G.noctalia_apply()'`, not `hyprctl dispatch` (dispatch wraps in `return hl.dispatch(...)`) and not `hyprctl reload` (re-runs hyprsplit and every bind).

## Hyprland

Files: `modules/home-manager/windowManager/hyprland/{default,config}.nix`, `flake.nix` (`hyprsplit` input)

hyprsplit is a Lua library (`flake = false`). The C++ plugin is deprecated and does not build against Hyprland ≥0.55. `~/.config/hypr/hyprsplit/init.lua` is copied from the input; Hyprland adds that dir to Lua `package.path`.

`extraConfig` **must** contain the literal substring `require("noctalia")` so Noctalia's hyprland `apply.sh` greps it and no-ops (it cannot append to a store symlink). Do not rewrite as `pcall(require, "noctalia")`. Numbered `-- N. Title` comments in `extraConfig` are parsed by the keybind cheatsheet; keep that exact form. Hyprland keysyms are case-insensitive and fire every match — do not bind `SUPER+L` alongside `SUPER+l`.

File manager is yazi in the terminal (thunar was never installed). Nautilus stays on SHIFT+E. `dim_inactive` stays off on a three-monitor desktop. Spring `speed` on animation leaves is dead config — retime by changing mass/stiffness/damping. Layer rules are required for bar/panel blur; do not blur `noctalia-wallpaper`.

hypr-dynamic-cursors builds against this Hyprland and still throws in `PLUGIN_INIT`. hyprexpo/hyprtrails/hyprwinwrap were deleted upstream; hyprspace 404s from the cache. No workspace overview on 0.56.2.

nm-applet is off (Noctalia's network widget). blueman and solaar stay — they provide pairing UIs Noctalia does not.

## Nix-mineral

File: `modules/nixos/core/nix-mineral.nix`. Host: `deadPc`.

`preset = "compatibility"` undoes desktop-hostile defaults (noexec on `/home`, hidepid, binfmt off, ptrace_scope=3, multilib off). Those broke the 2026-08-01 attempt. Overrides on top:

- `debugfs = true` — bcc/perf need it
- `panic-reboot = false` — default panic=-1 plus quiet boot is a silent reboot loop
- `coredump = true` — default PAM hard `core 0` makes `ulimit -c` useless
- `kicksecure-gitconfig = false` — would flatten symlinks on `git clone`
- `binfmt-misc = true` — `boot.binfmt.emulatedSystems` is dead without it
- `cpu-mitigations = "smt-on"` — smt-off halves this box to 12 threads
- `slab-debug = false` — allocator tax on every build
- `perf-subsystem.restrict-* = false`
- `random-mac = false` — desktop on a fixed LAN; breaks DHCP reservation and WoL
- `multilib = true` — PipeWire 32-bit + Wine

Prefer `nixos-rebuild boot` + reboot on this host so the prior generation stays bootable.

## Nvidia

File: `hosts/deadPc/config.nix`

Pin NVIDIA 595.99.02. nixpkgs 26.05 still ships 595.71.05, whose `strncpy()` was removed from the kernel API in Linux 7.2. Drop the pin once nixpkgs catches up. `graphics.enable32Bit` is for Wine, not Steam.

## DeadPi

Files: `hosts/deadPi/default.nix`, `hosts/deadPi/deploy.nix`

Mainline `linuxPackages_6_12` instead of nixos-hardware's raspberrypi fork. The fork was uncached (`linux-rpi-…` 404) and building it under qemu-aarch64 was abandoned. Tradeoff: no camera/unicam/codec patches — unused on this headless host. nixos-hardware uses `mkDefault`, so a plain assignment overrides it.

`activationTimeout = 1200` — an SD-card release upgrade can exceed deploy-rs defaults and trigger a spurious rollback.

## Claude-science

File: `pkgs/claude-science/default.nix`

**Do not patchelf or strip.** The binary is a Bun single-file executable: JS/assets sit after the ELF at absolute offsets in a trailer. Rewriting the ELF silently degrades to bare Bun (`--version` prints Bun's version). `dontPatchELF` / `dontStrip` plus a byte-identity check.

Interpreter stays `/lib64/ld-linux-x86-64.so.2`. The wrapper is bubblewrap overlaying a patched nix-ld, a bash/coreutils shim at `/bin`, and a real CA bundle. Use `--dev-bind /dev /dev` (GPU). Unset `NIX_LD` / `NIX_LD_LIBRARY_PATH` inside the sandbox — NixOS exports a `/run/...` loader that does not exist in the inner bwrap, and leaked `NIX_LD` panics nix-ld.

`src` points at the mutable `latest/` URL. A hash mismatch is the release signal, not corruption. Prefetch, update `hash`, run `--version` into `version`.

`packages.claude-science` in `per-system.nix` uses a locally-configured nixpkgs with `allowUnfree` — the shared perSystem `pkgs` does not.

## Helium

Files: `pkgs/helium/default.nix`, `pkgs/helium/{update,check}.sh`, `flake/modules/per-system.nix`

Not in nixpkgs. Prebuilt AppImage via `appimageTools.wrapType2` (FHS sandbox, not patchelf). Bump `version` + hashes from imputnet/helium-linux releases (`helium-update`, which must run against the git worktree). `check.sh` is cached, 2s-timeout, always exits 0 — nix-direnv re-evals the hook on every `cd`. extraPkgs: libva, pipewire, vulkan-loader. Desktop `Exec=` is rewritten to the wrapper.

## Ai-usagebar

File: `pkgs/ai-usagebar/default.nix`

Not in nixpkgs. Two plain ELFs; `autoPatchelfHook` + `libgcc` (libgcc_s is not in stdenv). Exists because the Noctalia plugin execs `ai-usagebar usage --json` by name. Tarball unpacks into CWD (`sourceRoot = "."`).

## Hosts

- **deadPc** — nix-mineral (boot + reboot). `upower` + `power-profiles-daemon` enabled directly (see Desktop). greetd + tuigreet, not SDDM/Plasma. 32-bit graphics for Wine.
- **deadConvertible** — overrides idle `lock-and-suspend` on; do not set `behavior_order` in the shared module.
- **deadRetro** — `nix run .#deadRetro`, not a nixosConfiguration. Wired in `per-system.nix` because it is NixOS 14.12. The runner requires `/dev/kvm` (config passes `-accel kvm -cpu host` with no fallback), unsets `LOCALE_ARCHIVE` (`LC_ALL=C`) because the host locale archive is newer than the 14.12 glibc, and `mkdir`s `~/.local/share/deadRetro` for the disk image.
- **deadPi** — see DeadPi. `enableHome = false`.
- **deadServer** — no Home Manager.

Pre-commit `check-added-large-files` is `--maxkb=20000` so wallpapers (including the 13MB video loop) can be committed without `--no-verify`.
