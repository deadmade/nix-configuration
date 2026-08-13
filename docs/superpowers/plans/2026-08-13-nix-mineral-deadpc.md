# nix-mineral on deadPc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable nix-mineral hardening on deadPc without regressing any development workflow on that host.

**Architecture:** Add the `nix-mineral` flake input, create a new `modules/nixos/hardening/` domain holding a single module that enables nix-mineral with the `compatibility` preset plus six explicit setting overrides, and import that module from `hosts/deadPc/config.nix` only. Placement outside `modules/nixos/core/` is deliberate: `profiles/nixos/core.nix` imports the core domain via `builtins.attrValues`, so a module there would silently apply to deadWsl, deadPi and deadServer.

**Tech Stack:** Nix flakes, flake-parts, NixOS 26.05, [nix-mineral](https://github.com/cynicsketch/nix-mineral), alejandra formatter, convco commit linting.

**Spec:** `docs/superpowers/specs/2026-08-13-nix-mineral-deadpc-design.md`

## Global Constraints

- **Commit messages must be Conventional Commits.** The `convco` pre-commit hook rejects anything else.
- **Precondition: the working tree must be clean before Task 1.** Verify with `git status --short` and stop if it lists anything other than untracked files this plan creates. The plan previously had to work around 11 unrelated modified files; that is resolved outside this plan.
- **Every commit MUST stage explicit paths.** Never run `git add -A`, `git add .`, `git add -p`, or `git commit -a`. Interactive git flags do not work in this environment.
- **New files under `modules/` must be `git add`ed before they evaluate.** `flake/lib/registry.nix` reads the flake source tree, and untracked files are invisible to flake evaluation.
- **Run `nix fmt` (alejandra) before committing any `.nix` file.** The pre-commit hook enforces it.
- **`nix flake check` emits informational warnings** about the custom outputs (`nixosProfiles`, `homeManagerModules`, …). These are expected and are not failures.
- **Only deadPc gets nix-mineral.** No other host's evaluated configuration may change.
- **Kernel parameters and mount options only take effect after a reboot.** Tasks 1–3 are verifiable by evaluation alone; Task 4 requires a reboot.

---

### Task 1: Add the nix-mineral flake input

**Files:**
- Modify: `flake.nix:157-160` (insert after the `nixsecauditor` block, before `deploy-rs`)
- Modify: `flake.lock` (regenerated)

**Interfaces:**
- Consumes: nothing.
- Produces: `inputs.nix-mineral.nixosModules.nix-mineral`, a NixOS module. Task 2 imports it.

- [ ] **Step 1: Write the failing check**

Confirm the input is genuinely absent, so the later check proves something:

```bash
nix flake metadata --json 2>/dev/null | grep -c '"nix-mineral"'
```

- [ ] **Step 2: Run it to verify it fails**

Expected: prints `0`. If it prints anything else, stop — the input already exists and this task is done.

- [ ] **Step 3: Add the input**

In `flake.nix`, immediately after the `nixsecauditor` block and before `deploy-rs`:

```nix
    nix-mineral = {
      type = "github";
      owner = "cynicsketch";
      repo = "nix-mineral";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

The `follows` is safe — upstream's own flake tracks `nixos-26.05`, matching this repo's `nixpkgs`.

- [ ] **Step 4: Lock it**

```bash
nix flake lock
```

- [ ] **Step 5: Run the check to verify it passes**

```bash
nix flake metadata --json 2>/dev/null | grep -c '"nix-mineral"'
```

Expected: a non-zero count.

Confirm the `follows` actually took effect — nix-mineral must not pull a second nixpkgs:

```bash
nix flake metadata --json 2>/dev/null | python3 -c \
  'import json,sys; d=json.load(sys.stdin); print(d["locks"]["nodes"]["nix-mineral"]["inputs"]["nixpkgs"])'
```

Expected: `nixpkgs` (a bare string naming the root node), not a list pointing at a separate node.

- [ ] **Step 6: Format and commit**

```bash
nix fmt flake.nix
git add flake.nix flake.lock
git commit -m "build(flake): add nix-mineral input"
```

---

### Task 2: Create the hardening module

**Files:**
- Create: `modules/nixos/hardening/nix-mineral.nix`

**Interfaces:**
- Consumes: `inputs.nix-mineral.nixosModules.nix-mineral` from Task 1.
- Produces: `outputs.nixosModules.hardening.nix-mineral`. Task 3 imports this exact attribute path.

The directory gets **no `default.nix`**. Per `flake/lib/registry.nix`, a subdirectory without one recurses into a nested registry keyed by filename minus `.nix` — which yields `hardening.nix-mineral`. Adding a `default.nix` would instead import the directory verbatim as a single module and break that path.

- [ ] **Step 1: Write the failing check**

```bash
nix eval .#nixosModules.hardening --apply builtins.attrNames
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL with `error: attribute 'hardening' missing`.

- [ ] **Step 3: Create the module**

Create `modules/nixos/hardening/nix-mineral.nix`:

```nix
{inputs, ...}: {
  imports = [inputs.nix-mineral.nixosModules.nix-mineral];

  nix-mineral = {
    enable = true;

    # Undoes the desktop-hostile defaults: noexec on /home, /tmp and /var/lib;
    # hidepid on /proc; binfmt_misc off; ptrace_scope=3; multilib off.
    # These are exactly the breakages that sank the 2026-08-01 attempt.
    preset = "compatibility";

    settings = {
      kernel = {
        # boot.binfmt.emulatedSystems on this host is dead without it.
        binfmt-misc = true;

        # Default "smt-off" would take this box from 24 threads to 12.
        cpu-mitigations = "smt-on";

        # Defaults true on kernels >= 6.17 (this host runs 7.1.8) and adds
        # allocator overhead to every build.
        slab-debug = false;

        # perf_event_max_sample_rate=1 and perf_cpu_time_max_percent=1 throttle
        # perf into uselessness, even as root.
        perf-subsystem.restrict-usage = false;

        # Keep the current perf_event_paranoid=2 rather than raising it to 3.
        perf-subsystem.restrict-access = false;
      };

      system = {
        # Default false sets ia32_emulation=0, killing 32-bit applications.
        # This host needs them: desktop/base.nix sets
        # services.pipewire.alsa.support32Bit, and 32-bit Wine needs
        # hardware.graphics.enable32Bit. The compatibility preset sets this
        # too; stated explicitly because this is the regression that forced
        # the old alsa.support32Bit mkForce hack.
        multilib = true;
      };
    };
  };
}
```

Settings written directly sit at Nix's normal priority (100) and beat the presets, which upstream applies at `mkOverride 800`. Lower numbers win, so every value above overrides `compatibility`.

- [ ] **Step 4: Track the file, then run the check to verify it passes**

The `git add` is required for evaluation, not just for the commit:

```bash
git add modules/nixos/hardening/nix-mineral.nix
nix eval .#nixosModules.hardening --apply builtins.attrNames
```

Expected: `[ "nix-mineral" ]`

- [ ] **Step 5: Verify no host picked it up yet**

Nothing imports a `hardening` domain via `attrValues`, so deadPc must still be unhardened at this point:

```bash
nix eval .#nixosConfigurations.deadPc.config.boot.kernelParams
```

Expected: the pre-existing list, with no `mitigations=auto` entry.

- [ ] **Step 6: Format and commit**

```bash
nix fmt modules/nixos/hardening/nix-mineral.nix
git add modules/nixos/hardening/nix-mineral.nix
git commit -m "feat(hardening): add nix-mineral module tuned for development"
```

---

### Task 3: Wire nix-mineral into deadPc

**Files:**
- Modify: `hosts/deadPc/config.nix:16` (the `imports` list)
- Modify: `CLAUDE.md:18` (restore the deleted reboot note)

**Interfaces:**
- Consumes: `outputs.nixosModules.hardening.nix-mineral` from Task 2.
- Produces: a hardened `nixosConfigurations.deadPc`. Task 4 builds and boots it.

- [ ] **Step 1: Write the failing checks**

Save this as `/tmp/claude-1000/-home-deadmade-nix-configuration/b5c1f3ab-ea45-4a3f-a68f-753d01b1e981/scratchpad/verify-mineral.sh`:

```bash
#!/usr/bin/env bash
# Asserts the evaluated deadPc config. No reboot required.
set -u
fail=0
check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected '$2', got '$3')"; fail=1; fi
}

params=$(nix eval --raw .#nixosConfigurations.deadPc.config.boot.kernelParams \
  --apply 'ps: builtins.concatStringsSep " " ps')
sysctl=$(nix eval .#nixosConfigurations.deadPc.config.boot.kernel.sysctl \
  --apply 'builtins.attrNames' --json)
homeopts=$(nix eval .#nixosConfigurations.deadPc.config.fileSystems --json \
  --apply 'fs: if fs ? "/home" then fs."/home".options else ["ABSENT"]')

# SMT stays enabled: mitigations=auto present, but never ",nosmt".
check "mitigations=auto present"      1 "$(grep -c 'mitigations=auto' <<<"$params")"
check "nosmt absent"                  0 "$(grep -c 'nosmt' <<<"$params")"
# 32-bit applications survive (multilib = true).
check "ia32_emulation=0 absent"       0 "$(grep -c 'ia32_emulation=0' <<<"$params")"
# slab-debug = false.
check "slab_debug absent"             0 "$(grep -c 'slab_debug' <<<"$params")"
check "hash_pointers absent"          0 "$(grep -c 'hash_pointers' <<<"$params")"
# binfmt-misc = true means the disabling sysctl is never written.
check "binfmt_misc.status unset"      0 "$(grep -c 'fs.binfmt_misc.status' <<<"$sysctl")"
# perf-subsystem fully relaxed.
check "perf_event_paranoid unset"     0 "$(grep -c 'perf_event_paranoid' <<<"$sysctl")"
check "perf_cpu_time unset"           0 "$(grep -c 'perf_cpu_time_max_percent' <<<"$sysctl")"
check "perf_max_sample_rate unset"    0 "$(grep -c 'perf_event_max_sample_rate' <<<"$sysctl")"
# Hardening that SHOULD be active.
check "kexec disabled"                1 "$(grep -c 'kernel.kexec_load_disabled' <<<"$sysctl")"
# /home is hardened but stays executable.
check "/home mounted"                 0 "$(grep -c 'ABSENT' <<<"$homeopts")"
check "/home noexec absent"           0 "$(grep -c '"noexec"' <<<"$homeopts")"
check "/home nosuid present"          1 "$(grep -c '"nosuid"' <<<"$homeopts")"

exit $fail
```

Make it executable:

```bash
chmod +x /tmp/claude-1000/-home-deadmade-nix-configuration/b5c1f3ab-ea45-4a3f-a68f-753d01b1e981/scratchpad/verify-mineral.sh
```

- [ ] **Step 2: Run it to verify it fails**

```bash
/tmp/claude-1000/-home-deadmade-nix-configuration/b5c1f3ab-ea45-4a3f-a68f-753d01b1e981/scratchpad/verify-mineral.sh
```

Expected: multiple `FAIL` lines and a non-zero exit. `mitigations=auto present`, `kexec disabled`, `/home mounted` and `/home nosuid present` all fail because nix-mineral is not applied yet.

- [ ] **Step 3: Add the import**

In `hosts/deadPc/config.nix`, the `imports` list currently ends:

```nix
    outputs.nixosProfiles.desktopAll
    outputs.nixosModules.virtualization.vmware
  ];
```

Change it to:

```nix
    outputs.nixosProfiles.desktopAll
    outputs.nixosModules.virtualization.vmware
    outputs.nixosModules.hardening.nix-mineral
  ];
```

- [ ] **Step 4: Run the checks to verify they pass**

```bash
/tmp/claude-1000/-home-deadmade-nix-configuration/b5c1f3ab-ea45-4a3f-a68f-753d01b1e981/scratchpad/verify-mineral.sh
```

Expected: every line `PASS`, exit 0.

If `kexec disabled` fails, the module did not apply at all — re-check the import path spelling. If only `/home noexec absent` fails, the `compatibility` preset did not load — re-check `preset = "compatibility"` in Task 2's module.

- [ ] **Step 5: Verify no other host changed**

This is the guard against the `core/` mistake the spec warns about:

```bash
nix eval --raw .#nixosConfigurations.deadServer.config.boot.kernelParams \
  --apply 'ps: builtins.concatStringsSep " " ps'
nix eval --raw .#nixosConfigurations.deadWsl.config.boot.kernelParams \
  --apply 'ps: builtins.concatStringsSep " " ps'
```

Expected: neither output contains `mitigations=auto`.

- [ ] **Step 6: Ensure the reboot note is present in CLAUDE.md**

This line was deleted at some point and nix-mineral makes it relevant again. First check whether it is already there:

```bash
grep -c 'nix-mineral.*hardened.*hosts' CLAUDE.md
```

If that prints `1`, the note survives — skip to Step 7 and note in your report that no CLAUDE.md change was needed. If it prints `0`, add it in `CLAUDE.md` under `Lower-level equivalents:`, directly after the `home-manager switch --flake .#deadmade@<host>` bullet:

```markdown
- For `nix-mineral` (hardened) hosts like `deadPc`, prefer `nixos-rebuild boot` + reboot so the prior generation stays bootable for rollback.
```

- [ ] **Step 7: Verify the full flake still evaluates**

```bash
nix flake check
```

Expected: succeeds. Informational warnings about `nixosProfiles` / `homeManagerModules` are expected and are not failures.

- [ ] **Step 8: Commit**

Stage only the files this task touched. If Step 6 found the note already present, omit `CLAUDE.md` from the `git add`:

```bash
git add hosts/deadPc/config.nix CLAUDE.md
git diff --cached
```

Expected: one added import line in `hosts/deadPc/config.nix`, plus at most one added line in `CLAUDE.md`. If the staged diff shows anything else, the working-tree precondition in Global Constraints was violated — stop and report rather than committing.

```bash
git commit -m "feat(deadPc): enable nix-mineral hardening"
```

---

### Task 4: Build, reboot, and verify at runtime

**Files:** none modified. This task validates the three preceding ones.

**Interfaces:**
- Consumes: the hardened `nixosConfigurations.deadPc` from Task 3.
- Produces: a verified running system, or a list of settings to relax.

- [ ] **Step 1: Record the pre-change baseline**

Run this **before** rebooting, so any regression is provable rather than remembered:

```bash
nproc
sysctl kernel.yama.ptrace_scope kernel.perf_event_paranoid
findmnt -no OPTIONS /home
```

Expected: `24`; `ptrace_scope = 1` and `perf_event_paranoid = 2`; `/home` options with no `noexec`.

- [ ] **Step 2: Build the system closure**

```bash
nix build .#nixosConfigurations.deadPc.config.system.build.toplevel
```

Expected: builds successfully. This also proves nix builds still work.

- [ ] **Step 3: Activate without switching**

Use `boot`, not `switch`, so the current generation stays bootable if the new one misbehaves:

```bash
sudo nixos-rebuild boot --flake .#deadPc
```

- [ ] **Step 4: Reboot**

This step is the user's to run; kernel parameters and mount options do not apply otherwise.

```bash
sudo reboot
```

If the machine fails to boot, select the previous generation in the GRUB menu — that is the rollback, and no cleanup is needed beyond reverting the Task 3 commit.

- [ ] **Step 5: Verify CPU and sysctls are unchanged**

```bash
nproc
sysctl kernel.yama.ptrace_scope kernel.perf_event_paranoid
grep -o 'ia32_emulation=[0-9]' /proc/cmdline || echo "ia32_emulation not disabled — correct"
grep -o 'mitigations=[a-z,]*' /proc/cmdline
```

Expected: `24` (SMT preserved); `ptrace_scope = 1` and `perf_event_paranoid = 2` (both unchanged from Step 1); no `ia32_emulation`; `mitigations=auto` with no `,nosmt`.

- [ ] **Step 6: Verify the original regression is gone**

This is the `python-auto-type` failure that sank the previous attempt:

```bash
# The venv interpreter must execute.
~/DHBWHeidenHeim_T3000/.venv/bin/python3 --version

# Any executable under python-auto-type/code must run rather than be blocked.
find ~/python-auto-type/code -type f -perm -u+x -print -quit \
  | xargs -r -I{} sh -c 'file {}; test -x {} && echo "executable bit honoured: {}"'

# A cargo build artefact must run.
find ~/Lingua-Serpentis/target -maxdepth 2 -type f -perm -u+x -print -quit \
  | xargs -r -I{} sh -c '{} --version 2>&1 | head -1 || echo "ran (non-zero exit is fine)"'
```

Expected: the venv python prints its version, and both `find` results execute. Any `Permission denied` means `noexec` reached `/home` and the `compatibility` preset did not apply — re-check Task 2's `preset` line.

- [ ] **Step 7: Verify containers, VMs and cross-compilation**

```bash
podman run --rm docker.io/library/alpine ping -c1 1.1.1.1
lsmod | grep -E 'vmmon|vmnet'
nix build .#nixosConfigurations.deadPi.config.system.build.toplevel --dry-run
```

Expected: the ping succeeds; both `vmmon` and `vmnet` are listed; the deadPi dry-run evaluates, exercising the aarch64 `binfmt_misc` path.

If `vmmon`/`vmnet` are missing, start VMware Workstation once to trigger the module build, then re-check. If they still fail, set `nix-mineral.settings.etc.kicksecure-module-blacklist = false;` in the Task 2 module.

- [ ] **Step 8: Verify 32-bit and audio**

```bash
grep -o 'ia32_emulation=[0-9]' /proc/cmdline || echo "32-bit exec enabled — correct"
pactl info | head -3
```

Expected: no `ia32_emulation=0`, and PipeWire reports a running server. Launch a 32-bit Wine application to confirm end to end.

- [ ] **Step 9: Check the residual risks the spec flagged**

```bash
lsmod | grep -E '^(gnss|can|garmin)' || echo "no GPS/CAN modules currently loaded"
```

If `chiplang-nix`'s `depthfinder`/`dfn-mounter` or the MNT Reform firmware work needs GPS or CAN hardware, test it now. The Kicksecure blacklist covers `gnss*`, `garmin_gps` and the whole `can*` family. Fix by setting `nix-mineral.settings.etc.kicksecure-module-blacklist = false;` in the Task 2 module, or keep the blacklist and add a targeted `boot.kernelModules` entry.

Likewise, `mount -t cifs` against deadPi's Samba server will fail while the blacklist is on. Browsing those shares through GVFS or Dolphin uses userspace `libsmbclient` and is unaffected.

- [ ] **Step 10: Switch to the new generation as default**

Once the checks above pass, make it the running configuration:

```bash
nos
```

- [ ] **Step 11: Commit any relaxations**

Only if Steps 7–9 forced a change to the Task 2 module. Name the specific breakage in the commit subject — for a blacklist rollback caused by GPS hardware, that is `fix(hardening): disable kicksecure module blacklist for gnss support`:

```bash
nix fmt modules/nixos/hardening/nix-mineral.nix
git add modules/nixos/hardening/nix-mineral.nix
git commit -m "fix(hardening): <specific setting> for <specific breakage>"
```

If Steps 7–9 all passed, skip this step — there is nothing to commit.

---

## Out of Scope

- Agent confinement (sandboxing what an AI agent can read and write). Separate spec.
- Consolidating project directories under `~/dev`, and the `noexec` on `/home` it would unlock.
- Enabling nix-mineral on any host other than deadPc.
