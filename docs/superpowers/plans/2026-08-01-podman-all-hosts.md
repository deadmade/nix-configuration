# deadConvertible + deadServer Podman Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `deadConvertible` and `deadServer` to the rootless Podman setup `deadPc` already runs, then delete the Docker module so the repo carries no Docker configuration.

**Architecture:** Both hosts currently direct-import `virtualization.docker` + `virtualization.vm` — exactly the pair the `virtualization` profile bundles (as `podman` + `vm`). Repoint both hosts at the profile, then delete `docker.nix` and its registry entry. Spec: `docs/superpowers/specs/2026-08-01-podman-all-hosts-design.md`.

**Tech Stack:** NixOS 26.05, flake-parts, Podman 5.8.2, docker-compose 5.1.4.

## Global Constraints

- Commit messages MUST be Conventional Commits — `convco` pre-commit hook rejects anything else.
- `nix fmt` (alejandra) runs as a pre-commit hook; formatting failures block commits.
- The working tree has unrelated modifications (`CLAUDE.md`, `flake.nix`, `flake.lock`, `hosts/deadPc/*`, `modules/nixos/core/nixsecauditor.nix` is staged, and others). Stage files explicitly by path. Never use `git add -A` or `git commit -a`.
- Flake evaluation only sees git-tracked files. Deleting a file requires `git rm` (not plain `rm`) or evaluation will still see the old tree.
- `virtualisation.podman.dockerCompat` and `virtualisation.docker.enable` are mutually exclusive by nixpkgs assertion — any leftover Docker import fails evaluation loudly.
- Booleans need plain `nix eval` (NOT `--raw`, which errors with "cannot coerce a Boolean to a string").
- Rebuilds of the two hosts happen on those machines, out of band. This session's exit criterion is evaluation-level verification.

Baseline, captured before any change:

| Host | `virtualisation.docker.enable` | `virtualisation.podman.enable` |
|---|---|---|
| deadPc | `false` | `true` |
| deadConvertible | `true` | `false` |
| deadServer | `true` | `false` |

---

### Task 1: Repoint both hosts at the virtualization profile

**Files:**
- Modify: `hosts/deadConvertible/config.nix:25-26`
- Modify: `hosts/deadServer/config.nix:17-18`

**Interfaces:**
- Consumes: `outputs.nixosProfiles.virtualization` — existing profile importing `virtualization.podman` + `virtualization.vm`.
- Produces: all three hosts on Podman. After this task `virtualization.docker` has zero consumers, which Task 2 relies on to delete it.

- [ ] **Step 1: Write the failing test**

The assertion this task must satisfy — every host on Podman, no `docker` group anywhere:

```bash
cd /home/deadmade/nix-configuration
for h in deadPc deadConvertible deadServer; do
  echo "$h docker=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.docker.enable") podman=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.podman.enable")"
done
for h in deadConvertible deadServer; do
  nix eval --json ".#nixosConfigurations.$h.config.users.users.deadmade.extraGroups"
done
```

Expected AFTER the task:
```
deadPc docker=false podman=true
deadConvertible docker=false podman=true
deadServer docker=false podman=true
```
and neither group list contains `docker`.

- [ ] **Step 2: Run it to confirm it currently fails**

Run the block above.
Expected NOW: `deadConvertible docker=true podman=false`, `deadServer docker=true podman=false`, and both group lists contain `docker`. This is the failing state.

- [ ] **Step 3: Edit deadConvertible**

In `hosts/deadConvertible/config.nix`, the import list currently ends:

```nix
      outputs.nixosModules.desktop.wayvnc
      outputs.nixosModules.virtualization.vm
      outputs.nixosModules.virtualization.docker
    ]
```

Replace the two `virtualization.*` lines with the profile:

```nix
      outputs.nixosModules.desktop.wayvnc
      outputs.nixosProfiles.virtualization
    ]
```

- [ ] **Step 4: Edit deadServer**

In `hosts/deadServer/config.nix`, the trailing import group currently reads:

```nix
    ++ [
      outputs.nixosModules.virtualization.docker
      outputs.nixosModules.virtualization.vm
    ];
```

Replace it with:

```nix
    ++ [
      outputs.nixosProfiles.virtualization
    ];
```

- [ ] **Step 5: Run the test to verify it passes**

Run the Step 1 block again.
Expected: all three hosts `docker=false podman=true`; neither migrated host's group list contains `docker`.

If evaluation fails with **"Option dockerCompat conflicts with docker"**, a Docker import survived — find it with `grep -rn "virtualization.docker" --include="*.nix" .` and remove it.

- [ ] **Step 6: Commit**

```bash
cd /home/deadmade/nix-configuration
git add hosts/deadConvertible/config.nix hosts/deadServer/config.nix
git commit -m "feat(virtualization): switch deadConvertible and deadServer to rootless podman" -- hosts/deadConvertible/config.nix hosts/deadServer/config.nix
```

---

### Task 2: Delete the Docker module

**Files:**
- Delete: `modules/nixos/virtualization/docker.nix`
- Modify: `modules/nixos/virtualization/default.nix`
- Modify: `docs/superpowers/specs/2026-08-01-podman-all-hosts-design.md` (status line)

**Interfaces:**
- Consumes: Task 1's result — `virtualization.docker` has no importers.
- Produces: registry without `docker`; the name `outputs.nixosModules.virtualization.docker` no longer exists.

- [ ] **Step 1: Write the failing test**

```bash
cd /home/deadmade/nix-configuration
nix eval '.#nixosModules.virtualization' --apply 'builtins.attrNames'
grep -rn "virtualization.docker" --include="*.nix" . ; echo "grep exit: $?"
```

Expected AFTER the task: `[ "podman" "vm" "vmware" ]` and the grep finds nothing (exit 1).

- [ ] **Step 2: Run it to confirm it currently fails**

Run the block above.
Expected NOW: `[ "docker" "podman" "vm" "vmware" ]`. This is the failing state.

- [ ] **Step 3: Delete the module**

```bash
cd /home/deadmade/nix-configuration
git rm modules/nixos/virtualization/docker.nix
```

- [ ] **Step 4: Update the registry**

Replace the whole of `modules/nixos/virtualization/default.nix` with:

```nix
{
  vm = import ./vm.nix;
  podman = import ./podman.nix;
  vmware = import ./vmware.nix;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run the Step 1 block again.
Expected: `[ "podman" "vm" "vmware" ]`, grep exit 1.

- [ ] **Step 6: Verify the whole flake still evaluates**

```bash
cd /home/deadmade/nix-configuration
nix flake check 2>&1 | tail -5
```

Expected: `all checks passed!`. Informational warnings about custom outputs (`nixosProfiles`, `homeManagerModules`, …) are expected and are not failures.

- [ ] **Step 7: Mark the spec implemented**

In `docs/superpowers/specs/2026-08-01-podman-all-hosts-design.md`, change the `**Status:**` line to:

```markdown
**Status:** Implemented 2026-08-01 (evaluation-verified; per-host runtime verification pending rebuilds)
```

- [ ] **Step 8: Commit**

```bash
cd /home/deadmade/nix-configuration
git add modules/nixos/virtualization/default.nix \
        docs/superpowers/specs/2026-08-01-podman-all-hosts-design.md
git commit -m "refactor(virtualization): delete docker module, all hosts on podman" \
  -- modules/nixos/virtualization/docker.nix \
     modules/nixos/virtualization/default.nix \
     docs/superpowers/specs/2026-08-01-podman-all-hosts-design.md
```

---

### Per-host runtime verification (out of band, on each machine)

Not a session task — run on `deadConvertible` and `deadServer` after pulling
this branch, per the spec's Verification section:

1. `sudo nixos-rebuild boot --flake .#<host>` then reboot.
2. Without `sudo`: `podman run --rm hello-world`, `docker ps`,
   `docker compose version`, `systemctl --user status podman.socket`,
   `podman info --format '{{.Host.Security.Rootless}}'` → `true`.
3. Only after step 2 passes: `sudo du -sh /var/lib/docker`, inspect, then
   `sudo rm -rf /var/lib/docker`.
