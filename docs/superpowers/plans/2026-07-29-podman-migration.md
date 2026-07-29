# deadPc Docker → rootless Podman Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Docker with rootless Podman on `deadPc`, keeping the `docker` command working via `dockerCompat`, while `deadConvertible` and `deadServer` stay on Docker.

**Architecture:** The Docker module is renamed `container.nix` → `docker.nix` and a new `podman.nix` is added alongside it. `deadPc` receives its container runtime through `desktopAll → virtualization` profile, so switching what that profile imports changes `deadPc` alone; the other two hosts import the module directly and are repointed to the new path with no behavioural change.

**Tech Stack:** NixOS 26.05, flake-parts, Podman 5.8.2, docker-compose 5.1.4.

## Global Constraints

- Scope is `deadPc` only. `deadConvertible` and `deadServer` MUST keep `virtualisation.docker.enable = true` throughout. Every task verifies this.
- `deadPc` runs `nix-mineral`, so per `CLAUDE.md` use `nixos-rebuild boot` + reboot, never `switch`. The prior generation must stay bootable.
- Commit messages MUST be Conventional Commits — `convco` runs as a pre-commit hook and rejects anything else.
- `nix fmt` (alejandra) runs as a pre-commit hook. Formatting failures block commits.
- `virtualisation.podman.dockerCompat` and `virtualisation.docker.enable` are mutually exclusive by assertion. Never set both in one host's config.
- The working tree has unrelated modifications (`flake.nix`, `flake.lock`, `hosts/deadPc/config.nix`, `modules/home-manager/coding/zed.nix`, `modules/nixos/desktop/packages.nix`). Stage files explicitly by path. Never use `git add -A` or `git commit -a`.

## How to test NixOS config

There is no unit-test framework. The test cycle is `nix eval` against the
evaluated configuration — this catches option values and assertion failures
without building or rebooting. Booleans need plain `nix eval` (NOT
`--raw`, which errors with "cannot coerce a Boolean to a string").

Baseline, captured before any change:

| Host | `virtualisation.docker.enable` | `virtualisation.podman.enable` |
|---|---|---|
| deadPc | `true` | `false` |
| deadConvertible | `true` | `false` |
| deadServer | `true` | `false` |

---

### Task 1: Rename the Docker module without changing behaviour

Pure refactor. Every host's evaluated config must be identical before and after.

**Files:**
- Rename: `modules/nixos/virtualization/container.nix` → `modules/nixos/virtualization/docker.nix` (content unchanged)
- Modify: `modules/nixos/virtualization/default.nix`
- Modify: `profiles/nixos/virtualization.nix`
- Modify: `hosts/deadConvertible/config.nix:26`
- Modify: `hosts/deadServer/config.nix:17`

**Interfaces:**
- Consumes: nothing.
- Produces: `outputs.nixosModules.virtualization.docker` — the Docker module, previously named `.container`. The name `.container` no longer exists after this task.

- [ ] **Step 1: Write the failing test**

Record the assertion this task must satisfy. All three hosts keep Docker, and
the old attribute name is gone:

```bash
cd /home/deadmade/nix-configuration
nix eval '.#nixosModules.virtualization' --apply 'builtins.attrNames'
```

Expected AFTER the task: `[ "docker" "vm" "vmware" ]`

- [ ] **Step 2: Run it to confirm it currently fails**

Run the command above.
Expected NOW: `[ "container" "vm" "vmware" ]` — no `docker` attribute. This is the failing state.

- [ ] **Step 3: Rename the file**

```bash
cd /home/deadmade/nix-configuration
git mv modules/nixos/virtualization/container.nix modules/nixos/virtualization/docker.nix
```

Do NOT edit the file contents. It stays exactly as-is:

```nix
{
  pkgs,
  vars,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lazydocker
  ];

  virtualisation = lib.mkForce {
    docker = {
      enable = true;
    };
    containers.enable = true;
  };
  users.users.${vars.username} = {
    extraGroups = ["docker"];
  };
}
```

- [ ] **Step 4: Update the registry**

Replace the whole of `modules/nixos/virtualization/default.nix` with:

```nix
{
  vm = import ./vm.nix;
  docker = import ./docker.nix;
  vmware = import ./vmware.nix;
}
```

- [ ] **Step 5: Update the three importers**

In `profiles/nixos/virtualization.nix`, change `outputs.nixosModules.virtualization.container` to `outputs.nixosModules.virtualization.docker`. Full file:

```nix
{outputs, ...}: {
  imports = [
    outputs.nixosModules.virtualization.docker
    outputs.nixosModules.virtualization.vm
  ];
}
```

In `hosts/deadConvertible/config.nix`, change the line reading
`outputs.nixosModules.virtualization.container` to
`outputs.nixosModules.virtualization.docker`.

In `hosts/deadServer/config.nix`, change the line reading
`outputs.nixosModules.virtualization.container` to
`outputs.nixosModules.virtualization.docker`.

- [ ] **Step 6: Confirm no references to the old name survive**

```bash
cd /home/deadmade/nix-configuration
grep -rn "virtualization.container" --include="*.nix" .
```

Expected: no output. Any hit is a missed importer — fix it before continuing.

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd /home/deadmade/nix-configuration
nix eval '.#nixosModules.virtualization' --apply 'builtins.attrNames'
for h in deadPc deadConvertible deadServer; do
  echo "$h docker: $(nix eval ".#nixosConfigurations.$h.config.virtualisation.docker.enable")"
done
```

Expected:
```
[ "docker" "vm" "vmware" ]
deadPc docker: true
deadConvertible docker: true
deadServer docker: true
```

All three still `true` — this task changed no behaviour.

- [ ] **Step 8: Commit**

`git mv` in Step 3 already staged the rename, so it is not listed again here.

```bash
cd /home/deadmade/nix-configuration
git add modules/nixos/virtualization/docker.nix \
        modules/nixos/virtualization/default.nix \
        profiles/nixos/virtualization.nix \
        hosts/deadConvertible/config.nix \
        hosts/deadServer/config.nix
git commit -m "refactor(virtualization): rename container module to docker"
```

---

### Task 2: Add the Podman module and point deadPc at it

**Files:**
- Create: `modules/nixos/virtualization/podman.nix`
- Modify: `modules/nixos/virtualization/default.nix`
- Modify: `profiles/nixos/virtualization.nix`

**Interfaces:**
- Consumes: `outputs.nixosModules.virtualization.docker` from Task 1 (stays registered, still used by the two other hosts).
- Produces: `outputs.nixosModules.virtualization.podman`. After this task the `virtualization` profile provides Podman, not Docker.

- [ ] **Step 1: Write the failing test**

The assertion for this task — deadPc flips to Podman, the other two do not move:

```bash
cd /home/deadmade/nix-configuration
for h in deadPc deadConvertible deadServer; do
  echo "$h docker=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.docker.enable") podman=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.podman.enable")"
done
nix eval --json '.#nixosConfigurations.deadPc.config.users.users.deadmade.extraGroups'
```

Expected AFTER the task:
```
deadPc docker=false podman=true
deadConvertible docker=true podman=false
deadServer docker=true podman=false
```
and the deadPc group list must NOT contain `docker`.

- [ ] **Step 2: Run it to confirm it currently fails**

Run the block above.
Expected NOW: `deadPc docker=true podman=false`, and the group list is
`["networkmanager","wheel","networkmanager","wheel","dialout","docker"]` —
containing `docker`. This is the failing state.

- [ ] **Step 3: Create the Podman module**

Create `modules/nixos/virtualization/podman.nix`:

```nix
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lazydocker
    docker-compose
  ];

  virtualisation = {
    podman = {
      enable = true;
      # Symlinks `docker` -> `podman`, so `docker compose up` becomes
      # `podman compose up` and delegates to the docker-compose provider.
      dockerCompat = true;
      # Docker enables inter-container DNS implicitly; podman does not.
      defaultNetwork.settings.dns_enabled = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    containers.enable = true;
  };

  # Point Docker-API clients at the rootless socket instead of
  # /var/run/docker.sock. Verified to expand in Task 3.
  environment.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
}
```

Note there is deliberately no `users.users.<name>.extraGroups` entry. The
`podman` group gates the **rootful** socket and would defeat running rootless.

- [ ] **Step 4: Register it**

Replace `modules/nixos/virtualization/default.nix` with:

```nix
{
  vm = import ./vm.nix;
  docker = import ./docker.nix;
  podman = import ./podman.nix;
  vmware = import ./vmware.nix;
}
```

- [ ] **Step 5: Switch the profile**

Replace `profiles/nixos/virtualization.nix` with:

```nix
{outputs, ...}: {
  imports = [
    outputs.nixosModules.virtualization.podman
    outputs.nixosModules.virtualization.vm
  ];
}
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
cd /home/deadmade/nix-configuration
for h in deadPc deadConvertible deadServer; do
  echo "$h docker=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.docker.enable") podman=$(nix eval ".#nixosConfigurations.$h.config.virtualisation.podman.enable")"
done
nix eval --json '.#nixosConfigurations.deadPc.config.users.users.deadmade.extraGroups'
nix eval '.#nixosConfigurations.deadPc.config.virtualisation.podman.dockerCompat'
```

Expected:
```
deadPc docker=false podman=true
deadConvertible docker=true podman=false
deadServer docker=true podman=false
```
group list has no `docker`; `dockerCompat` is `true`.

If evaluation instead fails with **"Option dockerCompat conflicts with
docker"**, something still imports the Docker module into deadPc. Find it with
`grep -rn "virtualization.docker" --include="*.nix" .` and confirm the
`desktopAll` → `virtualization` profile chain is the only route.

- [ ] **Step 7: Verify the whole flake still evaluates**

```bash
cd /home/deadmade/nix-configuration
nix flake check 2>&1 | tail -20
```

Expected: completes. Per `CLAUDE.md`, informational warnings about the custom
outputs (`nixosProfiles`, `homeManagerModules`, …) are expected and are not
failures.

- [ ] **Step 8: Commit**

```bash
cd /home/deadmade/nix-configuration
git add modules/nixos/virtualization/podman.nix \
        modules/nixos/virtualization/default.nix \
        profiles/nixos/virtualization.nix
git commit -m "feat(virtualization): switch deadPc to rootless podman"
```

---

### Task 3: Build, reboot, and verify at runtime

Evaluation proves the options are set; only a running system proves rootless
Podman works. This task also resolves the one open question in the spec.

**Files:**
- Possibly modify: `modules/home-manager/core/homeConfig.nix` (only if Step 4 fails)

**Interfaces:**
- Consumes: the Podman module from Task 2.
- Produces: a confirmed-working `DOCKER_HOST`. No new Nix attributes.

- [ ] **Step 1: Build the new generation without activating it**

```bash
cd /home/deadmade/nix-configuration
sudo nixos-rebuild boot --flake .#deadPc
```

Expected: builds and installs the bootloader entry. `boot`, not `switch` —
`deadPc` runs `nix-mineral` and the prior generation must stay bootable.

- [ ] **Step 2: Reboot**

```bash
sudo reboot
```

- [ ] **Step 3: Verify the rootless socket is running**

```bash
systemctl --user status podman.socket
```

Expected: `active (listening)`. Note this is `--user`, not a system unit.

- [ ] **Step 4: Check DOCKER_HOST expanded**

This is the open question flagged in the spec.

```bash
echo "$DOCKER_HOST"
```

Expected: `unix:///run/user/1000/podman/podman.sock` — an expanded absolute path.

**If it prints a literal `$XDG_RUNTIME_DIR`**, PAM did not expand it. Apply the
fallback: add this line to `modules/home-manager/core/homeConfig.nix`, next to
the existing `home.sessionVariables.NIXOS_OZONE_WL = "1";` on line 11:

```nix
  home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
```

then remove the `environment.sessionVariables.DOCKER_HOST` line from
`modules/nixos/virtualization/podman.nix`, run `nhs` (`nh home switch .`),
start a new login session, and re-check. Home Manager writes the value into the
shell profile, where expansion is guaranteed.

- [ ] **Step 5: Verify the runtime as your normal user**

Every command below runs WITHOUT `sudo`. Needing `sudo` means it is not rootless.

```bash
podman run --rm hello-world
docker ps
docker compose version
podman info --format '{{.Host.Security.Rootless}}'
```

Expected: the hello-world container prints its greeting and exits; `docker ps`
shows an empty table (not a socket error); `docker compose version` reports
Docker Compose `v5.1.4`; the last command prints `true`.

- [ ] **Step 6: Verify inter-container DNS**

This confirms `dns_enabled` took effect — the setting Docker gives implicitly
and Podman does not.

```bash
podman network inspect podman --format '{{.DNSEnabled}}'
```

Expected: `true`

- [ ] **Step 7: Commit (only if the Step 4 fallback was applied)**

If Step 4 succeeded, there is nothing to commit — skip this step.

```bash
cd /home/deadmade/nix-configuration
git add modules/home-manager/core/homeConfig.nix \
        modules/nixos/virtualization/podman.nix
git commit -m "fix(virtualization): set DOCKER_HOST via home-manager for reliable expansion"
```

---

### Task 4: Reclaim the orphaned Docker state

Deliberately last, manual, and after a confirmed-working Podman. Roughly 8 GB.

**Files:** none — this touches only `/var/lib/docker` on disk.

**Interfaces:** none.

- [ ] **Step 1: Confirm Podman is genuinely working first**

Do not proceed unless Task 3 Step 5 passed. This step is irreversible and the
old state is the only rollback material.

- [ ] **Step 2: Look at what will be deleted**

```bash
sudo du -sh /var/lib/docker
sudo ls /var/lib/docker/volumes | head -40
```

Expected: about 8 GB, and volumes named `act-*`, `gcl-*`,
`deadbot-cluster_redis-*`. All confirmed unused.

- [ ] **Step 3: Delete it**

```bash
sudo rm -rf /var/lib/docker
```

- [ ] **Step 4: Verify the space came back**

```bash
df -h /var
ls /var/lib/docker 2>&1
```

Expected: reduced usage on `/var`; the `ls` reports "No such file or directory".

- [ ] **Step 5: Update the spec status**

In `docs/superpowers/specs/2026-07-29-podman-migration-design.md`, change the
`**Status:**` line to `Implemented 2026-07-29`.

```bash
cd /home/deadmade/nix-configuration
git add docs/superpowers/specs/2026-07-29-podman-migration-design.md
git commit -m "docs(virtualization): mark podman migration spec implemented"
```
