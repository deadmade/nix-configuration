# Auto-discovered module registries

**Date:** 2026-08-01
**Status:** Approved

## Goal

Stop hand-maintaining `default.nix` registry files under `modules/`. Adding a
module file should register it automatically, while keeping the existing
module → profile → host composition (named cherry-picking via
`outputs.nixosModules.<domain>.<name>`) exactly as it is.

Denix and literal import-tree were considered and rejected: both replace
selective import-based composition with import-everything semantics. Haumea
was rejected as a dependency whose conventions (notably around `default.nix`)
conflict with this repo's layout. Decision: a small in-repo helper.

## The helper: `flake/lib/registry.nix`

A plain function `dir → attrset`, using only `builtins.readDir`, `import`,
and basic string operations. For each entry in `dir`:

| Entry | Result |
|---|---|
| `<name>.nix` file (not `default.nix`) | attr `<name>` = `import` of the file |
| directory containing `default.nix` | attr `<name>` = `import` of the directory (opt-out: treated as a single module or hand-written registry) |
| directory without `default.nix`, containing entries | attr `<name>` = recursive registry of that directory |
| empty directory | skipped |
| any other file | skipped |

Attr names are taken verbatim from filenames (no case conversion):
`grub2-bootloader.nix` → `grub2-bootloader`, `nix-index.nix` → `nix-index`.

The opt-out rule preserves today's real module directories:
`modules/home-manager/windowManager/hyprland/`, `modules/home-manager/gaming/`,
`modules/home-manager/flatpak/`, `modules/home-manager/terminal/kitty/`,
`modules/home-manager/terminal/starship/`.

The recursion rule turns `modules/home-manager/windowManager/` into a nested
registry, so the hyprland module moves from `homeManagerModules.hyprland` to
`homeManagerModules.windowManager.hyprland`.

## Wiring change

`flake/modules/exports.nix`:

```nix
nixosModules = registry ../../modules/nixos;
homeManagerModules = registry ../../modules/home-manager;
```

where `registry = import ../lib/registry.nix`. Profiles
(`profiles/*/default.nix`), overlays, and `hosts/hosts.nix` are out of scope
and unchanged.

## Deletions

Eleven pure-registry files are removed:

- `modules/nixos/default.nix`, `modules/home-manager/default.nix`
- `modules/nixos/{core,desktop,gaming,virtualization}/default.nix`
- `modules/home-manager/{core,browser,coding,terminal,socialMedia}/default.nix`

Also delete the stray empty directory `modules/home-manager/terminal/tmux/`
(untracked; would otherwise be skipped by the empty-dir rule anyway).

## Reference updates

Only two call sites reference an attr whose auto-derived name differs from
its current hand-written name:

- `profiles/home-manager/desktop-dev.nix`:
  `outputs.homeManagerModules.hyprland` →
  `outputs.homeManagerModules.windowManager.hyprland`
- `profiles/home-manager/wsl.nix`:
  `outputs.homeManagerModules.core.home` →
  `outputs.homeManagerModules.core.homeConfig`

Three attrs rename without any call-site impact (consumed only via
`builtins.attrValues`): `coding.vscode` → `coding.vscodium`,
`terminal.nixIndex` → `terminal.nix-index`, `core.home` → `core.homeConfig`.

## Behavioral contract change

With auto-discovery, any `.nix` file dropped into a domain directory is
registered immediately; if a profile imports that domain via
`builtins.attrValues`, the module is active on the next rebuild. Today this
is a no-op (every existing file is already registered — verified by diffing
directory listings against the hand-written registries), but it is the
contract going forward: work-in-progress modules must live outside
`modules/`, or in a directory guarded by a `default.nix`.

## Verification

1. Before the change: `nix eval` the `attrNames` (recursively, per domain) of
   `nixosModules` and `homeManagerModules`; save the output.
2. After the change: re-run and diff. The only deltas must be the renames
   listed above (plus the disappearance of nothing — no attrs may be lost).
3. `nix flake check` (informational warnings for custom outputs are
   expected).
4. Dry-run builds:
   `nix build .#nixosConfigurations.deadPc.config.system.build.toplevel --dry-run`
   and the corresponding `homeConfigurations."deadmade@deadPc"` activation
   package, proving composition is eval-identical.

## Error handling

- A name collision (e.g. `foo.nix` next to `foo/`) would silently produce a
  single attr today; the helper must instead `throw` with the offending path
  so collisions surface at eval time.
- Non-registry garbage (editor swap files, READMEs) is skipped by the
  "other file" rule and cannot break evaluation.

## Testing

No test framework exists in this repo; verification steps 1–4 above are the
test. They run before commit per the repo's pre-commit conventions.
