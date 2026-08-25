# Migrate deadConvertible and deadServer to rootless Podman, remove Docker

**Date:** 2026-08-01
**Status:** Implemented 2026-08-01 (evaluation-verified; per-host runtime verification pending rebuilds)
**Scope:** `deadConvertible` and `deadServer`. Completes what
`2026-07-29-podman-migration-design.md` started on `deadPc`; after this change
no host uses Docker and the Docker module is deleted.

## Goal

Move the two remaining Docker hosts to the same rootless Podman setup deadPc
now runs, then remove `modules/nixos/virtualization/docker.nix` and its
registry entry so the repo carries no Docker configuration at all.

## Background

After the deadPc migration, `virtualization.docker` has exactly two consumers,
both direct imports:

| Host | Today imports | Docker usage (user-confirmed) |
|---|---|---|
| `deadConvertible` | `virtualization.docker` + `virtualization.vm` | nothing to keep |
| `deadServer` | `virtualization.docker` + `virtualization.vm` | unused |

Neither host defines container-backed NixOS services (`oci-containers`,
compose systemd units) — Docker there was only ever for ad-hoc user
containers. Nothing needs to auto-start at boot and nothing binds privileged
ports, so rootless Podman fits both hosts without lingering or a rootful
socket.

Both hosts import exactly the module pair that the `virtualization` profile
bundles (`podman` + `vm` since the deadPc migration). Hosts can import
profiles directly — `deadPc` already does (`outputs.nixosProfiles.desktopAll`).

## Design

### 1. Repoint both hosts at the profile

In `hosts/deadConvertible/config.nix` and `hosts/deadServer/config.nix`,
replace the two import lines

```nix
outputs.nixosModules.virtualization.docker
outputs.nixosModules.virtualization.vm
```

with the single profile import

```nix
outputs.nixosProfiles.virtualization
```

All three hosts then share one source of truth for their container runtime.
The alternative — repointing each direct import at `virtualization.podman` —
was rejected: it duplicates what the profile already expresses.

### 2. Delete the Docker module

- Delete `modules/nixos/virtualization/docker.nix`.
- Remove the `docker` entry from `modules/nixos/virtualization/default.nix`.

The `dockerCompat` ↔ `docker.enable` assertion in nixpkgs is the safety net:
any surviving Docker import anywhere fails evaluation loudly.

`podman.nix` is reused unchanged; it is host-agnostic (rootless,
`dockerCompat`, compose v2 provider, `DOCKER_HOST`, weekly auto-prune). Its
known limitation carries over: default-network DNS is rootful-only, and
compose-created networks provide DNS regardless (see the deadPc spec,
verified 2026-08-01).

### 3. Cleanup of old Docker state

`/var/lib/docker` on each host is orphaned. As on deadPc, removal is a
manual, documented step run only after that host's Podman is verified —
never automated in a rebuild.

## Verification

1. `nix eval`: all three hosts report `docker=false podman=true`; neither
   migrated host has `docker` in `extraGroups`.
2. `nix flake check` passes (custom-output warnings expected).
3. Per host, after rebuild + reboot, as the normal user without `sudo`:
   `podman run --rm hello-world`, `docker ps`, `docker compose version`,
   `systemctl --user status podman.socket`, and
   `podman info --format '{{.Host.Security.Rootless}}'` → `true`.
4. Only then, per host: inspect and delete `/var/lib/docker`.

Rebuilds of `deadConvertible` and `deadServer` happen on those machines and
are out of band for the implementing session; the session's exit criterion is
the evaluation-level verification plus documented runtime steps.

## Out of scope

Boot-time containers on `deadServer` (would need lingering or the rootful
socket — its own spec if ever wanted), `podman-compose`, `podman-tui`, NVIDIA
container toolkit. `deadWsl` keeps `wsl.docker-desktop`; `deadPi`'s commented
Docker line stays untouched.

## Accepted consequences

`docker` becomes a podman symlink on all hosts; all Docker images and volumes
on both machines are discarded without migration (confirmed nothing worth
keeping). Re-running any project means re-pulling base images.
