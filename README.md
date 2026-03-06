# nix-configuration

Personal NixOS + Home Manager flake configuration for multiple hosts.

## Repository layout

- `hosts/`: host-specific NixOS and Home Manager entrypoints (`deadPc`, `deadConvertible`, `deadServer`, `deadWsl`, `deadPi`)
- `modules/nixos/`: reusable NixOS modules grouped by domain (`core`, `desktop`, `virtualization`, `arion`)
- `modules/home-manager/`: reusable Home Manager modules
- `profiles/nixos/` and `profiles/home-manager/`: higher-level module bundles used by hosts
- `flake/modules/`: flake-parts wiring for outputs, host builders, and per-system tooling

## Common commands

- `nix flake show --all-systems`
- `nix flake check`
- `sudo nixos-rebuild switch --flake .#<host>`
- `home-manager switch --flake .#deadmade@<host>`

## Notes on flake outputs

This repo intentionally exports custom flake outputs such as `homeManagerModules`,
`homeManagerProfiles`, and `nixosProfiles` in addition to standard outputs.
`nix flake check` may show informational warnings for these custom outputs.

## Assets

Wallpapers source: https://wall.alphacoders.com/
