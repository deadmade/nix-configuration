# deadPi deploy-rs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `deadPi`'s NixOS closure on `deadPc` and push it to the Pi over SSH with one command, with automatic rollback if the deployment breaks the machine.

**Architecture:** Add `deploy-rs` as a flake input. Per-host deploy metadata lives in `hosts/<name>/deploy.nix` — a plain attrset that the NixOS evaluation never sees, because `hosts/hosts.nix` imports the host *directory* and so only ever reads `default.nix`. A new flake-parts module, `flake/modules/deploy.nix`, discovers those files and assembles the `deploy.nodes` flake output, attaching each host's activation package from `config.flake.nixosConfigurations`.

**Tech Stack:** Nix flakes, flake-parts, deploy-rs, NixOS 26.05, aarch64 via qemu binfmt emulation.

**Spec:** `docs/superpowers/specs/2026-08-02-deadpi-deploy-rs-design.md`

---

## Preconditions

**These must be true before Task 1. Do not skip.**

1. **The working tree must be clean for `flake.nix` and `flake.lock`.**

   At the time of writing, the branch `feat/podman-migration` has uncommitted
   changes to `CLAUDE.md`, `flake.lock`, `flake.nix`, `hosts/deadPc/config.nix`,
   `hosts/deadPc/home.nix`, `modules/home-manager/coding/zed.nix`,
   `modules/nixos/desktop/packages.nix`, `pkgs/helium/default.nix`, and
   `pkgs/helium/update.sh`.

   Task 3 modifies `flake.nix` and regenerates `flake.lock`. If those files
   still carry the podman work, `git add flake.nix flake.lock` will sweep
   unrelated changes into a deploy commit.

   Resolve first — commit the podman work, or `git stash push flake.nix
   flake.lock`. Verify with:

   ```bash
   git status --short flake.nix flake.lock
   ```

   Expected: **no output**.

   The modified `flake.lock` also matters for a second reason: it changes the
   nixpkgs pin, which changes `deadPi`'s closure. Task 6 depends on knowing
   exactly what is being deployed.

2. **Tasks 1 and 6 require a human at the keyboard.** Task 1 runs
   `ssh-copy-id`, which prompts for the Pi's password interactively. Task 6
   performs the first real deployment to a headless machine. An agentic worker
   must stop and hand these to the user rather than attempt them.

---

## Global Constraints

- **Formatter:** `alejandra`. Run `nix fmt .` (with the dot — bare `nix fmt` makes alejandra read stdin and fail) before every commit; the pre-commit hook enforces it and will reject unformatted `.nix` files.
- **Commit messages:** Conventional Commits, enforced by `convco` in the pre-commit hook.
- **Git visibility:** flake evaluation only sees **git-tracked** files. Every new `.nix` file must be `git add`ed before any `nix eval` / `nix build` that references it, or it will appear not to exist.
- **Input style:** new flake inputs use the structured `type`/`owner`/`repo` attribute form, matching every existing input in `flake.nix`.
- **`inputs.nixpkgs.follows = "nixpkgs"`** on the deploy-rs input, per the spec's recorded trade-off.
- **Do not modify `hosts/hosts.nix`.** Deploy metadata lives in `hosts/<name>/deploy.nix`.
- **Do not touch the sd-image configuration.** `useSdImageInstaller = true` stays exactly as it is; it is out of scope per the spec.
- **Target:** `deadPi`, hostname `10.10.10.137`, `sshUser = "admin"`, `user = "root"`.
- **deadmade's public key** (used verbatim in Task 7):
  `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBHA2a226b67E3wsCDfY7kgrZCCXju7E+4HNrfykglZ3 manuel.schuelein@proton.me`

**On "tests" in this plan:** this is a Nix configuration repo with no unit-test
framework. The test cycle is `nix eval` / `nix build` / `nix flake check` plus
SSH assertions against the live Pi. Every task still follows the same shape:
observe the current state failing, make the change, observe it passing.

---

### Task 1: Bootstrap SSH key authentication to deadPi

**Requires a human.** `ssh-copy-id` prompts for a password.

**Files:** none — this task changes no repository content. Its deliverable is
working key-based SSH plus a verified answer to the spec's one unverified
assumption (passwordless sudo).

**Interfaces:**
- Consumes: nothing.
- Produces: key-based SSH as `admin@10.10.10.137`, and a known answer to
  "does `sudo -n` succeed?" — Task 4 needs that answer to decide whether
  `hosts/deadPi/deploy.nix` requires `interactiveSudo = true`.

- [ ] **Step 1: Confirm key auth currently fails**

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 admin@10.10.10.137 true; echo "exit=$?"
```

Expected: `admin@10.10.10.137: Permission denied (publickey,password,keyboard-interactive).` and `exit=255`.

If this unexpectedly succeeds, key auth is already set up — skip to Step 3.

- [ ] **Step 2: Copy the public key**

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@10.10.10.137
```

You will be prompted for `admin`'s password on the Pi. This appends the key to
`~admin/.ssh/authorized_keys` on the Pi. Task 7 replaces this imperative step
with a declarative one; this exists only to break the chicken-and-egg.

- [ ] **Step 3: Verify key auth now works**

```bash
ssh -o BatchMode=yes admin@10.10.10.137 'hostname; echo OK'
```

Expected:
```
deadpi
OK
```

- [ ] **Step 4: Verify passwordless sudo**

```bash
ssh -o BatchMode=yes admin@10.10.10.137 'sudo -n true; echo "sudo_exit=$?"'
```

Expected: `sudo_exit=0`.

This confirms the spec's inferred claim that
`profiles/installation-device.nix` sets `security.sudo.wheelNeedsPassword =
mkImageMediaOverride false` and that `hosts/deadPi/default.nix` does not
override it.

**If `sudo_exit` is non-zero**, record that fact and add `interactiveSudo =
true;` to `hosts/deadPi/deploy.nix` in Task 4. Everything else in the plan is
unchanged.

- [ ] **Step 5: Verify admin is a trusted Nix user**

```bash
ssh -o BatchMode=yes admin@10.10.10.137 'nix show-config 2>/dev/null | grep trusted-users || nix config show trusted-users'
```

Expected: output containing `admin`. This is what allows `nix copy` from
deadPc to be accepted by the Pi's daemon. It is declared at
`hosts/deadPi/default.nix:142`.

- [ ] **Step 6: No commit**

This task changes no tracked files. Do not commit.

---

### Task 2: Verify deadPc can build deadPi's closure

**Files:** none — verification only.

**Interfaces:**
- Consumes: nothing.
- Produces: proof that emulated `aarch64-linux` building works end to end, and
  the store path of `deadPi`'s current `toplevel`, which Task 6 compares
  against what the Pi is actually running.

- [ ] **Step 1: Confirm binfmt emulation is registered**

```bash
cat /proc/sys/fs/binfmt_misc/aarch64-linux
nix config show extra-platforms
```

Expected: the first prints `enabled` and `interpreter /run/binfmt/aarch64-linux`;
the second includes `aarch64-linux`. Both come from
`hosts/deadPc/config.nix:21-27`.

- [ ] **Step 2: Build deadPi's system closure on deadPc**

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPi.config.system.build.toplevel
```

Expected: a `/nix/store/...-nixos-system-deadpi-...` path on stdout.

This may take a long time on first run. Most store paths substitute from
`cache.nixos.org`, which has `aarch64-linux` binaries for nixos-26.05;
anything from this repo's own overlays is built under qemu emulation.

If it fails, stop and diagnose here. Nothing after this point can work until
deadPc can build for the Pi.

- [ ] **Step 3: Record the store path**

```bash
nix eval --raw .#nixosConfigurations.deadPi.config.system.build.toplevel
```

Save this value. Task 6 Step 2 compares it against the Pi's running system.

- [ ] **Step 4: No commit**

This task changes no tracked files. Do not commit.

---

### Task 3: Add the deploy-rs flake input

**Files:**
- Modify: `flake.nix` (inputs block)
- Modify: `flake.lock` (regenerated)

**Interfaces:**
- Consumes: nothing.
- Produces: `inputs.deploy-rs`, supplying `inputs.deploy-rs.lib.<system>.activate.nixos`
  (a function from a nixosConfiguration to an activation package) and
  `inputs.deploy-rs.packages.<system>.default` (the `deploy` binary, with
  `meta.mainProgram = "deploy"`). Task 4 uses both.

- [ ] **Step 1: Confirm the input does not exist yet**

```bash
nix flake metadata --json | python3 -c "import json,sys; print('deploy-rs' in json.load(sys.stdin)['locks']['nodes'])"
```

Expected: `False`.

- [ ] **Step 2: Add the input**

In `flake.nix`, add this block inside `inputs`, immediately after the closing
brace of the existing `nixsecauditor` block and before the closing brace of
`inputs`:

```nix
    deploy-rs = {
      type = "github";
      owner = "serokell";
      repo = "deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 3: Lock the new input**

```bash
nix flake lock
```

Expected: output reporting `• Added input 'deploy-rs':` along with its
transitive inputs (`deploy-rs/utils`, `deploy-rs/flake-compat`).

- [ ] **Step 4: Verify the input resolves**

```bash
nix flake metadata --json | python3 -c "import json,sys; print(json.load(sys.stdin)['locks']['nodes']['deploy-rs']['locked']['rev'])"
```

Expected: a 40-character git revision.

- [ ] **Step 5: Verify the `follows` took effect**

```bash
nix flake metadata --json | python3 -c "import json,sys; print(json.load(sys.stdin)['locks']['nodes']['deploy-rs']['inputs']['nixpkgs'])"
```

Expected: `['nixpkgs']` — a single-element list. That is how a resolved
`follows` is encoded in `flake.lock`: an input path relative to the root node.
Every existing `follows` input in this repo looks the same — `home-manager`,
`nixcord`, `solaar`, and `git-hooks` all yield `['nixpkgs']`.

For the stronger check that deploy-rs did not drag in its own nixpkgs, confirm
the lock gained no new nixpkgs node for it:

```bash
nix flake metadata --json | python3 -c "import json,sys; n=json.load(sys.stdin)['locks']['nodes']; print(n['deploy-rs']['inputs'])"
```

Expected: `nixpkgs` maps to `['nixpkgs']`, not to a private node name like
`nixpkgs_13`.

This is the trade-off the spec records: deploy-rs now builds against the 26.05
pin and will not hit deploy-rs's own cachix, costing one emulated aarch64 Rust
build in Task 6.

That `deploy-rs.lib.<system>.activate.nixos` actually exists is verified in
Task 4 Step 7, which fails loudly if it does not.

- [ ] **Step 6: Format and commit**

```bash
nix fmt .
git add flake.nix flake.lock
git commit -m "build(flake): add deploy-rs input"
```

Verify the commit contains only those two files:

```bash
git show --stat --name-only HEAD
```

Expected: exactly `flake.nix` and `flake.lock`.

---

### Task 4: Add the deploy output

**Files:**
- Create: `hosts/deadPi/deploy.nix`
- Create: `flake/modules/deploy.nix`
- Modify: `flake.nix` (imports list in `outputs`)

**Interfaces:**
- Consumes: `inputs.deploy-rs.lib.<system>.activate.nixos` and
  `inputs.deploy-rs.packages.<system>.default` from Task 3;
  `hostDefinitions` (injected as a `_module.args` by
  `flake/modules/constants.nix:14`); `config.flake.nixosConfigurations`
  (set by `flake/modules/hosts.nix`).
- Produces: the flake output `deploy.nodes.deadPi` with `hostname`,
  `sshUser`, `user`, `magicRollback`, `autoRollback`, and
  `profiles.system.path`; plus `apps.<system>.deploy`, which Task 5's alias
  and Task 6's deployment both invoke as `nix run .#deploy`.

- [ ] **Step 1: Confirm the output does not exist yet**

```bash
nix eval .#deploy.nodes.deadPi.hostname
```

Expected: failure — `error: flake 'git+file:///home/deadmade/nix-configuration' does not provide attribute ... 'deploy'`.

- [ ] **Step 2: Create the per-host deploy metadata**

Create `hosts/deadPi/deploy.nix`:

```nix
{
  hostname = "10.10.10.137";
  sshUser = "admin";
  user = "root";
  magicRollback = true;
  autoRollback = true;
}
```

`sshUser` is who deploy-rs connects as; `user` is who the activation runs as,
reached via `sudo`. If Task 1 Step 4 reported a non-zero `sudo_exit`, add
`interactiveSudo = true;` to this attrset.

This file sits beside `default.nix` but is never seen by the NixOS
evaluation: `hosts/hosts.nix:32` lists `./deadPi`, and importing a directory
resolves to its `default.nix` alone.

- [ ] **Step 3: Create the flake-parts module**

Create `flake/modules/deploy.nix`:

```nix
{
  inputs,
  hostDefinitions,
  config,
  ...
}: let
  lib = inputs.nixpkgs.lib;

  # hosts/<name>/deploy.nix is a plain attrset, not a NixOS module: the host
  # directory is imported as ./<name>, which resolves to default.nix only.
  deployFileFor = name: ../../hosts + "/${name}/deploy.nix";

  deployHosts = lib.filterAttrs (name: _: builtins.pathExists (deployFileFor name)) hostDefinitions;

  mkNode = name: hostConfig:
    lib.recursiveUpdate (import (deployFileFor name)) {
      profiles.system.path =
        inputs.deploy-rs.lib.${hostConfig.system}.activate.nixos
        config.flake.nixosConfigurations.${name};
    };
in {
  flake.deploy.nodes = lib.mapAttrs mkNode deployHosts;

  perSystem = {system, ...}: {
    apps.deploy = {
      type = "app";
      program = lib.getExe inputs.deploy-rs.packages.${system}.default;
    };
  };
}
```

`lib.recursiveUpdate` rather than `//` so a host that later declares its own
`profiles` attribute does not have it silently replaced.

- [ ] **Step 4: Register the module**

In `flake.nix`, add `./flake/modules/deploy.nix` to the `imports` list inside
`flake-parts.lib.mkFlake`, after `./flake/modules/per-system.nix`:

```nix
      imports = [
        ./flake/modules/constants.nix
        ./flake/modules/exports.nix
        ./flake/modules/hosts.nix
        ./flake/modules/home.nix
        ./flake/modules/per-system.nix
        ./flake/modules/deploy.nix
      ];
```

- [ ] **Step 5: Stage the new files so the flake can see them**

```bash
git add hosts/deadPi/deploy.nix flake/modules/deploy.nix
```

Untracked files are invisible to flake evaluation. Skipping this makes the
next step fail with a confusing "path does not exist" error.

- [ ] **Step 6: Verify the node metadata evaluates**

```bash
nix eval .#deploy.nodes.deadPi.hostname
nix eval .#deploy.nodes.deadPi.sshUser
nix eval .#deploy.nodes.deadPi.magicRollback
```

Expected:
```
"10.10.10.137"
"admin"
true
```

- [ ] **Step 7: Verify the activation package resolves**

```bash
nix eval --raw .#deploy.nodes.deadPi.profiles.system.path
```

Expected: a `/nix/store/...-activatable-nixos-system-deadpi-...` path.

This evaluates without building. The actual build happens in Task 6 and
includes one qemu-emulated aarch64 Rust build of deploy-rs itself, because
`activate.nixos` embeds the deploy-rs binary for the *target* system and the
`follows = "nixpkgs"` chosen in Task 3 rules out a cachix hit.

- [ ] **Step 8: Verify only deadPi produced a node**

```bash
nix eval .#deploy.nodes --apply builtins.attrNames
```

Expected: `[ "deadPi" ]`. No other host has a `deploy.nix` yet.

- [ ] **Step 9: Verify the app is wired up**

```bash
nix eval --raw .#apps.x86_64-linux.deploy.program
```

Expected: a store path ending in `/bin/deploy`.

- [ ] **Step 10: Run the flake checks**

```bash
nix flake check
```

Expected: passes. It emits an informational warning about `deploy` being an
unknown flake output, exactly as it already does for `nixosModules`,
`homeManagerModules`, `nixosProfiles`, and `homeManagerProfiles`. That warning
is expected and is not a failure.

- [ ] **Step 11: Format and commit**

```bash
nix fmt .
git add flake.nix hosts/deadPi/deploy.nix flake/modules/deploy.nix
git commit -m "feat(deploy): add deploy-rs node for deadPi"
```

---

### Task 5: Add the `nospi` alias

**Files:**
- Modify: `modules/home-manager/core/aliases.nix`

**Interfaces:**
- Consumes: `apps.<system>.deploy` from Task 4.
- Produces: the shell alias `nospi`, available after the next `nhs`.

- [ ] **Step 1: Confirm the alias does not exist yet**

```bash
nix eval '.#homeConfigurations."deadmade@deadPc".config.home.shellAliases' --apply builtins.attrNames
```

Expected: a list containing `nos`, `nhs`, `nosf`, `nhsf` — and **not** `nospi`.

- [ ] **Step 2: Add the alias**

Edit `modules/home-manager/core/aliases.nix` to read in full:

```nix
{
  home.shellAliases = {
    nos = "nh os switch .";
    nhs = "nh home switch .";
    nosf = "nh os switch . --update";
    nhsf = "nh home switch . --update";
    nospi = "nix run .#deploy -- .#deadPi";
  };
}
```

Like `nos` and `nhs`, this is relative to the current directory and must be
run from the repository root.

- [ ] **Step 3: Verify the alias evaluates**

```bash
nix eval --raw '.#homeConfigurations."deadmade@deadPc".config.home.shellAliases.nospi'
```

Expected: `nix run .#deploy -- .#deadPi`

- [ ] **Step 4: Format and commit**

```bash
nix fmt .
git add modules/home-manager/core/aliases.nix
git commit -m "feat(aliases): add nospi for deploying deadPi"
```

- [ ] **Step 5: Note for later**

The alias only becomes usable after a Home Manager rebuild (`nhs`). Task 6
deliberately uses the full `nix run` command so it does not depend on that.

---

### Task 6: First deployment

**Requires a human.** This is the first deployment to a headless machine.

**Files:** none — verification only.

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: a proven deployment pipeline. Task 7 relies on it.

- [ ] **Step 1: Record what the Pi is running now**

```bash
ssh admin@10.10.10.137 'readlink -f /nix/var/nix/profiles/system'
```

Save this value.

- [ ] **Step 2: Compare against what deadPc will deploy**

```bash
nix eval --raw .#nixosConfigurations.deadPi.config.system.build.toplevel
```

Compare with Step 1.

**They will differ, and by a lot.** As of 2026-08-02 the Pi runs NixOS 25.11
with kernel 6.12.47, while this repo targets 26.05 with kernel 6.18.34. The
first deploy is therefore a full release upgrade plus a six-minor-version
kernel jump — not the byte-identical no-op an earlier draft of this plan
assumed. There is no flake state that makes those match.

The transport-only test you actually get is Step 3's `--dry-activate`, which
exercises build, copy, SSH and sudo without changing the running system.

Do not proceed straight to deploying. Step 4 inspects the difference once both
closures are on the Pi.

Note what rollback does *not* cover: `magicRollback` reverts if the Pi stops
answering SSH after activation, but not if the Pi activates successfully and
then fails to **boot**. A kernel change rewrites `extlinux.conf`, and choosing
an older generation from the boot menu needs a screen or serial console. Treat
physical access to the SD card as the real safety net for this step.

- [ ] **Step 3: Dry-activate**

```bash
nix run .#deploy -- --dry-activate .#deadPi
```

Expected: deploy-rs builds the closure, copies it to the Pi, and runs
`switch-to-configuration dry-activate`, printing what *would* change without
changing it. This is the step where the emulated aarch64 deploy-rs build
happens if it has not already.

Expected exit code 0. The Pi's running system is unchanged — confirm:

```bash
ssh admin@10.10.10.137 'readlink -f /nix/var/nix/profiles/system'
```

Expected: still the Step 1 value.

- [ ] **Step 4: Review the closure diff, on the Pi**

Run this **on the Pi**, not on deadPc. `nix store diff-closures` needs both
closures present in the same store, and deadPc does not have the Pi's *old*
system. After Step 3 the Pi has both.

```bash
NEW=$(nix eval --raw .#nixosConfigurations.deadPi.config.system.build.toplevel)
ssh admin@10.10.10.137 "nix store diff-closures /nix/var/nix/profiles/system $NEW"
```

Read the output. Confirm the changes are ones you expect from ordinary nixpkgs
drift, and that nothing touches networking, sshd, or the `fileSystems` entries
for `/`, `/mnt/disks/*`, or `/storage`. **Do not proceed on a diff you cannot
explain** — this is the last checkpoint before the Pi actually changes.

If Step 2 showed the paths were identical, this diff will be empty. That is
the expected and best case.

- [ ] **Step 5: Deploy for real**

```bash
nix run .#deploy -- .#deadPi
```

Expected: activation succeeds, then deploy-rs opens a **fresh** SSH connection
to confirm the machine is still reachable. On success it prints a confirmation
and exits 0.

If the Pi becomes unreachable, `magicRollback` reverts to the previous
generation automatically after `confirmTimeout`. If the activation script
itself fails, `autoRollback` reverts. Either way the Pi ends up on the Step 1
system.

- [ ] **Step 6: Verify the Pi is healthy**

```bash
ssh admin@10.10.10.137 'readlink -f /nix/var/nix/profiles/system; systemctl is-system-running; systemctl is-active restic-rest-server; findmnt -n /storage /mnt/disks/sda1 /mnt/disks/sdb1 /mnt/disks/sdc1'
```

Expected: the profile now points at the path from Step 2; `systemctl
is-system-running` reports `running` (or `degraded` with an explanation you
recognise); `restic-rest-server` is `active` — that is the unit name
`services.restic.server` produces, enabled at `hosts/deadPi/default.nix:103`;
and all four mounts are listed, with `/storage` showing `fuse.mergerfs`.

- [ ] **Step 7: No commit**

This task changes no tracked files. Do not commit.

---

### Task 7: Declare the SSH key in the Pi's config

**Files:**
- Modify: `hosts/deadPi/default.nix` (the `users.users.admin` block)

**Interfaces:**
- Consumes: the working pipeline from Task 6.
- Produces: key authentication that survives a fresh flash, rather than
  depending on the imperative `ssh-copy-id` from Task 1.

- [ ] **Step 1: Confirm the key is currently only imperative**

```bash
ssh admin@10.10.10.137 'ls -la /etc/ssh/authorized_keys.d/admin 2>&1; wc -l < ~/.ssh/authorized_keys'
```

Expected: `/etc/ssh/authorized_keys.d/admin` does not exist (NixOS has not
been told about any key), while `~/.ssh/authorized_keys` has 1 line — the one
`ssh-copy-id` wrote.

- [ ] **Step 2: Add the declarative key**

This is a pure insertion. In `hosts/deadPi/default.nix`, inside the
`users.users.admin` block (which begins at line 136), add these three lines
immediately **after** the existing line:

```nix
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
```

Lines to insert:

```nix
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBHA2a226b67E3wsCDfY7kgrZCCXju7E+4HNrfykglZ3 manuel.schuelein@proton.me"
    ];
```

**Do not modify, retype, reformat, or reindent any other line in that block.**
In particular the `hashedPassword` line below it must be left byte-for-byte
untouched. It is a known issue tracked separately in the spec's "Related
finding" section, and this task is not the place to change it.

Confirm you inserted and changed nothing else:

```bash
git diff --stat hosts/deadPi/default.nix
```

Expected: `1 file changed, 3 insertions(+)` — three insertions, **zero
deletions**. Any deletion means you rewrote a line you should not have.

- [ ] **Step 3: Verify the key is in the evaluated config**

```bash
nix eval .#nixosConfigurations.deadPi.config.users.users.admin.openssh.authorizedKeys.keys
```

Expected: a single-element list containing the `ssh-ed25519 ...` string above.

- [ ] **Step 4: Format and commit**

```bash
nix fmt .
git add hosts/deadPi/default.nix
git commit -m "feat(deadPi): declare deadmade's ssh key for admin"
```

- [ ] **Step 5: Dry-activate, then review the diff on the Pi**

```bash
nix run .#deploy -- --dry-activate .#deadPi
```

Expected: exit 0, and the Pi's running system unchanged.

The dry-activate has now copied the new closure to the Pi, so both are present
in the same store and the diff can be taken there:

```bash
NEW=$(nix eval --raw .#nixosConfigurations.deadPi.config.system.build.toplevel)
ssh admin@10.10.10.137 "nix store diff-closures /nix/var/nix/profiles/system $NEW"
```

Expected: a small diff. This is the first deployment that changes anything, so
confirm it changes only what you intend. If Task 6 deployed cleanly and
nothing else has moved, the only difference should be the system closure
itself — an `authorizedKeys` change alters generated `/etc` content rather
than pulling in new packages, so expect no version changes in the listing.

- [ ] **Step 6: Deploy**

```bash
nix run .#deploy -- .#deadPi
```

Expected: exit 0 with the magic-rollback confirmation.

- [ ] **Step 7: Verify the key is now declarative**

```bash
ssh admin@10.10.10.137 'cat /etc/ssh/authorized_keys.d/admin'
```

Expected: the `ssh-ed25519 AAAAC3...` line.

- [ ] **Step 8: Verify key auth still works from a clean connection**

```bash
ssh -o BatchMode=yes admin@10.10.10.137 'echo STILL_OK'
```

Expected: `STILL_OK`.

`~/.ssh/authorized_keys` from Task 1 still exists and is still honoured —
NixOS does not remove it. Deleting it is optional; if you want to confirm the
declarative path works on its own, move it aside and re-run this step before
deciding.

---

## Done

After Task 7, `nospi` (or `nix run .#deploy -- .#deadPi`) builds deadPi on
deadPc and deploys it with rollback protection.

**Deliberately not done here**, per the spec: splitting the sd-image installer
out of `nixosConfigurations.deadPi`, `deployChecks` integration with `nix flake
check`, unattended/scheduled deployment, and the public-repo password hashes at
`hosts/deadPi/default.nix:132` and `:139`.
