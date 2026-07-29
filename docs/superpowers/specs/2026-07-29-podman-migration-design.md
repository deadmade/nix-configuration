# Migrate deadPc from Docker to rootless Podman

**Date:** 2026-07-29
**Status:** Approved, ready for planning
**Scope:** `deadPc` only. `deadConvertible` and `deadServer` keep Docker.

## Goal

Replace Docker with rootless Podman on `deadPc`, with `dockerCompat` so the
`docker` command and Docker-API tooling keep working. Compose support comes from
the real Compose v2 binary.

## Background

`modules/nixos/virtualization/container.nix` currently configures Docker:

```nix
virtualisation = lib.mkForce {
  docker.enable = true;
  containers.enable = true;
};
users.users.${vars.username}.extraGroups = ["docker"];
environment.systemPackages = [pkgs.lazydocker];
```

It reaches three hosts by two different routes:

| Host | Route |
|---|---|
| `deadPc` | `desktopAll` profile → `virtualization` profile → `container` |
| `deadConvertible` | direct import of `outputs.nixosModules.virtualization.container` |
| `deadServer` | direct import of `outputs.nixosModules.virtualization.container` |

No other host uses the `virtualization` profile, and no host uses the `desktop`
profile, so changing what that profile imports affects `deadPc` alone.

### Verified against nixpkgs 26.05

Checked in the locked nixpkgs rather than assumed:

- `virtualisation.podman.dockerCompat` carries an assertion that it conflicts
  with `virtualisation.docker.enable`. The two cannot coexist, so this is a
  swap rather than a gradual migration.
- The podman module already sets
  `systemd.user.sockets.podman.wantedBy = ["sockets.target"]`, so the rootless
  user socket needs no extra wiring.
- `autoSubUidGidRange` defaults to `true` for normal users, so subuid/subgid
  mappings need no manual configuration.
- The module creates a `podman` group, but it gates the **rootful** socket.
- Podman is 5.8.2. `podman compose` is a thin wrapper that delegates to an
  external provider found on `PATH`, preferring `docker-compose` over
  `podman-compose`.

### Existing state (to be discarded)

`deadPc` holds roughly 8 GB of Docker images and a set of volumes: `act-*`
(GitHub Actions runner), `gcl-*` (gitlab-ci-local), `deadbot-cluster_redis-*`,
and a stopped `WinBoat` container. The user confirmed none of it is still in
use, so no migration path is required.

## Design

### 1. Module layout

Rename for clarity, so the registry names the runtime it configures:

- `modules/nixos/virtualization/container.nix` → `docker.nix`, content unchanged
- new `modules/nixos/virtualization/podman.nix`
- `modules/nixos/virtualization/default.nix` exposes both `docker` and `podman`
- `profiles/nixos/virtualization.nix` imports `virtualization.podman`
- `hosts/deadConvertible/config.nix` and `hosts/deadServer/config.nix` repoint
  their direct imports to `virtualization.docker`

The two host edits are import-path changes with no behavioural effect. The
alternative — leaving a module named `container` that means Docker while the
profile silently points elsewhere — was rejected as more confusing than the
churn is worth.

### 2. The podman module

```nix
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lazydocker
    docker-compose
  ];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    containers.enable = true;
  };

  environment.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
}
```

Rationale for each non-obvious line:

- `dockerCompat` installs a shim that symlinks `docker` → `podman`. As a
  consequence `docker compose up` resolves to `podman compose up`, which then
  delegates to the `docker-compose` provider. Both command spellings work.
- `defaultNetwork.settings.dns_enabled` enables DNS resolution between
  containers on the default network. Docker provides this implicitly; Podman
  does not.
- `DOCKER_HOST` points Docker-API clients (`lazydocker`, `docker-compose`,
  anything else expecting `/var/run/docker.sock`) at the rootless socket.

**Open implementation detail:** `environment.sessionVariables` reaches sessions
through both `/etc/set-environment` (shell-sourced, expands `$XDG_RUNTIME_DIR`)
and PAM (which does not expand reliably). The literal `$XDG_RUNTIME_DIR` form
must therefore be confirmed to expand in a real session before this is
considered done — `echo $DOCKER_HOST` after reboot. If it arrives unexpanded,
fall back to setting it in Home Manager, where the value is written into the
shell profile and expansion is guaranteed. Hardcoding `/run/user/1000` is a last
resort, since it bakes in a UID.

Three deliberate deletions from the current module:

- **`lib.mkForce`** — nothing else in the configuration sets these options, so
  it is noise. Forcing an entire `virtualisation` attrset is also a hazard as
  sibling modules accumulate, and `deadPc` already imports
  `virtualization.vmware`.
- **`extraGroups = ["docker"]`** — the `docker` group will not exist, which
  fails evaluation.
- **no `podman` group substitute** — that group grants access to the rootful
  socket, which would quietly defeat the purpose of running rootless.

### 3. Cleanup of old Docker state

`/var/lib/docker` is orphaned by this change. Podman neither reads nor migrates
it.

Removal stays a **manual, documented step**, deliberately not automated: an
`rm -rf` over 8 GB of data does not belong in a system rebuild, and the
directory is worth one look before it goes.

### 4. Verification

1. `nix flake check`
2. `nixos-rebuild boot` and reboot — per `CLAUDE.md`, `deadPc` runs
   `nix-mineral`, so the previous generation must stay bootable for rollback.
   (`nix-mineral.enable` is currently `false`, so no hardening interference is
   expected.)
3. As the normal user, with no `sudo`:
   - `podman run --rm hello-world`
   - `docker ps`
   - `docker compose version`
   - `systemctl --user status podman.socket`

## Out of scope

Explicitly excluded, to be added only on request: `podman-compose`,
`podman-tui`, the rootful socket (`dockerSocket.enable`), and the NVIDIA
container toolkit. `deadPi` (Docker commented out) and `deadWsl`
(`wsl.docker-desktop`) are untouched — neither imports this module.

## Accepted consequences

After this change, `docker` on `deadPc` is a symlink to `podman`, and all
existing images and volumes are gone. Rebuilding any project's containers will
require re-pulling base images. This is irreversible and was confirmed as
acceptable.
