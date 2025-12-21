# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

This repository uses `nh` (nix-helper) for building and updating. Common aliases defined in `modules/home-manager/core/aliases.nix`:

```bash
# NixOS system rebuild
nos         # nh os switch .
nosf        # nh os switch . --update (updates flake.lock first)

# Home-manager rebuild
nhs         # nh home switch .
nhsf        # nh home switch . --update

# Manual alternatives (if nh is unavailable)
sudo nixos-rebuild switch --flake .#deadPc
home-manager switch --flake .#deadmade@deadPc

# Update flake inputs
nix flake update

# Format all Nix files (uses alejandra)
nix fmt

# Enter development shell (includes pre-commit hooks, sops, age, colmena)
nix develop
```

## Repository Architecture

### Flake-Based Configuration

This is a flake-based NixOS configuration tracking stable 25.11 plus unstable packages. The flake outputs:

- **nixosConfigurations**: System configurations (deadPc, deadConvertible, deadWsl, deadPi)
- **homeConfigurations**: User configurations (deadmade@<host>)
- **nixosModules**: Reusable system-level modules
- **homeManagerModules**: Reusable user-level modules
- **customModules**: Custom NixOS extensions (e.g., firejail sandboxing)
- **overlays**: Package modifications and unstable access

### Host Structure

Each host in `hosts/<hostname>/` contains:
- `config.nix` - NixOS system configuration
- `hardware-configuration.nix` - Auto-generated hardware specs
- `home.nix` - Home-manager user configuration
- `sops.nix` - Secrets management (optional, currently only deadPc)

Active hosts:
- **deadPc**: Desktop with 3x 1920x1080 monitors, NVIDIA GPU, Hyprland
- **deadConvertible**: Laptop with AMD GPU, touchpad/wacom support
- **deadWsl**: Windows Subsystem for Linux configuration
- **deadPi**: Raspberry Pi ARM configuration (aarch64-linux)

### Module Organization

Two-tier module system:

**NixOS Modules** (`modules/nixos/`):
- `core/` - System fundamentals (packages, user, localization, security, network, themes, bootloader)
- `desktop/` - Desktop features (packages, stylix theming, VPN, JetBrains, gaming, AI, bluetooth)
- `virtualization/` - Docker, Arion (Docker Compose in Nix), VMs
- `funshit/` - Optional/experimental features

**Home-Manager Modules** (`modules/home-manager/`):
- `core/` - User fundamentals (home config, git, btop, nix config, stylix, aliases)
- `terminal/` - Terminal tools (kitty, starship, tmux, zsh, fastfetch, ghostty)
- `windowManager/` - Hyprland + components (waybar, hyprlock, hypridle, wofi, swaync, wpaperd, wlogout)
- `browser/` - Browser configs (firefox, librewolf, floorp)
- `coding/` - Development environments
- `gaming/`, `socialMedia/`, `flatpak/` - Specialized features

### Module Composition Patterns

Modules are imported using `outputs.<moduleType>.<category>.<module>`:

```nix
# Single module import
outputs.nixosModules.desktop.packages

# Import all modules from a category
++ (builtins.attrValues outputs.nixosModules.core)
++ (builtins.attrValues outputs.homeManagerModules.core)

# Nested sub-modules (e.g., Hyprland auto-imports waybar, hyprlock, etc.)
outputs.homeManagerModules.hyprland
```

### Key Conventions

**Variables System** (`variables.nix`):
- Shared configuration values passed via `specialArgs = {inherit vars;}`
- Contains: `username`, `gitUsername`, `gitEmail`, `browser`, `terminal`, `keyboardLayout`, `consoleKeyMap`
- Modify this file to change defaults across all hosts

**Overlays** (`overlays/default.nix`):
- `flake-inputs` - Exposes flake input packages as `pkgs.inputs.*`
- `unstable-packages` - Access unstable packages via `pkgs.unstable.*`
- `modifications` - Custom package patches (e.g., logiops fix)

**SpecialArgs Passing**:
All configurations receive `{inherit inputs outputs vars;}` via specialArgs, making these available in all modules without explicit imports.

## Adding New Hosts

1. Create `hosts/<hostname>/` directory with:
   - `config.nix` - Import modules from `outputs.nixosModules.*`
   - `hardware-configuration.nix` - Generate via `nixos-generate-config`
   - `home.nix` - Import modules from `outputs.homeManagerModules.*`

2. Add to `flake.nix`:
```nix
nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
  specialArgs = {inherit inputs outputs vars;};
  modules = [ ./hosts/<hostname>/config.nix ];
};

homeConfigurations."${vars.username}@<hostname>" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  extraSpecialArgs = {inherit inputs outputs vars;};
  modules = [ ./hosts/<hostname>/home.nix ];
};
```

## Adding New Modules

**NixOS Module**:
1. Create `modules/nixos/<category>/<name>.nix`
2. Export in `modules/nixos/default.nix` under appropriate category
3. Import in host's `config.nix` via `outputs.nixosModules.<category>.<name>`

**Home-Manager Module**:
1. Create `modules/home-manager/<category>/<name>/default.nix` (or `<name>.nix`)
2. Export in `modules/home-manager/default.nix` under appropriate category
3. Import in host's `home.nix` via `outputs.homeManagerModules.<category>.<name>`

## Secrets Management

Uses `sops-nix` with age encryption:
- Keys defined per-host in `.sops.yaml`
- Secrets stored encrypted in `secrets/` directory
- Import `sops.nix` in host config to decrypt secrets at build time
- Use `sops <file>` to edit encrypted files

## Pre-Commit Hooks

Development shell (`nix develop`) automatically enables git hooks:
- **alejandra** - Nix code formatting (same as `nix fmt`)
- **deadnix** - Remove dead/unused Nix code
- **convco** - Conventional commit message validation
- **check-merge-conflicts**, **end-of-file-fixer**, **trufflehog**

Hooks run automatically on `git commit`. To bypass (not recommended): `git commit --no-verify`

## Containerization with Arion

Arion provides Docker Compose integration in Nix:
- Infrastructure services: `modules/nixos/virtualization/arion/infrastructure/`
- Nextcloud setup: `modules/nixos/virtualization/arion/nextcloud/`
- Define services declaratively in Nix, built via Docker

## Custom Modules

**Firejail Sandboxing** (`custom-modules/firejail/`):
- Defines 1,319+ sandboxed program options
- Enable per-program: `programs.firejail.<program>.enable = true;`
- Auto-detects executable paths and creates wrapper scripts

## Flake Inputs

Key external dependencies:
- **nixpkgs** (25.11 stable), **nixpkgs-unstable**
- **home-manager** (25.11)
- **stylix** - System-wide theming framework
- **sops-nix** - Secrets management
- **arion** - Docker Compose in Nix
- **nixos-hardware** - Hardware-specific configurations
- **git-hooks** - Pre-commit hook management
- **colmena** - Multi-machine deployment
- **neovim-config** - External Neovim configuration repository

## System State Versions

Each host pins a state version (e.g., 24.11) for compatibility. This determines which NixOS module defaults are used and should rarely change after initial setup.
