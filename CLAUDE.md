# CLAUDE.md

Personal NixOS + Home Manager flake (`deadPc`, `deadConvertible`, `deadServer`, `deadWsl`, `deadPi`). Built on flake-parts. Full write-up: [`docs/architecture.md`](docs/architecture.md). Decisions and traps: [`docs/decisions.md`](docs/decisions.md). Index: [`docs/README.md`](docs/README.md).

## Commands

Rebuild uses `nh`, aliased in `modules/home-manager/core/aliases.nix`:

- `nos` → `nh os switch .`
- `nhs` → `nh home switch .`
- `nosf` / `nhsf` — same with `--update`

Lower-level: `sudo nixos-rebuild switch --flake .#<host>` and `home-manager switch --flake .#deadmade@<host>`. On nix-mineral hosts (`deadPc`) prefer `nixos-rebuild boot` + reboot so the prior generation stays bootable.

Checks and formatting:

- `nix flake check` — custom outputs (`nixosModules`, `homeManagerModules`, …) emit informational warnings; expected
- `nix fmt` / `alejandra` — formatter. `nix develop` installs pre-commit (alejandra, convco, trufflehog, merge-conflict, large-file). Commit messages must be Conventional Commits
- `nix develop` — `lazygit`, `ripgrep`, `curl`, `helium-update`

## Architecture (short)

Wiring lives in `flake/modules/`. `exports.nix` builds registries from `modules/` via `flake/lib/registry.nix` (`foo.nix` → attr; dir with `default.nix` → one module; dir without → nested registry). Hosts import modules by name; there is no profile layer and no custom `mkOption`. Inside any module, `outputs` is this repo's registry.

**Add a module:** create the `.nix` under the right domain, then add `outputs.nixosModules.<domain>.<name>` (or home-manager equivalent) to **each host** that should get it. Untracked files are invisible to flake evaluation.

**Add a host:** entry in `hosts/hosts.nix` plus `hosts/<name>/`.

Overlays: `pkgs.unstable.*`, `pkgs.inputs.<flake>`, custom `pkgs/` via `additions`. Shared Stylix base: `flake/lib/theme.nix`.

## Comments

Do not add restating comments. Durable why goes in `docs/decisions.md`. Keep shebangs, the local `neovim-config` flake-input toggle, and the numbered `-- N. Title` headings in Hyprland `extraConfig` (the cheatsheet plugin parses them).

## Read before editing

- noctalia / hyprland / stylix / theme / gtk / qt → `docs/decisions.md` `#desktop` `#noctalia-plugins` `#hyprland`
- nix-mineral → `#nix-mineral`
- `pkgs/claude-science` → `#claude-science` (do not patchelf)
- helium → `#helium`
- deadPc nvidia pin → `#nvidia`
- deadPi kernel / deploy timeouts → `#deadpi`
