# Re-add nix-mineral to deadPc, tuned for development

**Date:** 2026-08-13
**Status:** Approved, ready for implementation planning
**Scope:** deadPc only

## Goal

Enable [nix-mineral](https://github.com/cynicsketch/nix-mineral) on deadPc without
regressing any development workflow on that host.

This reverses part of `2026-08-01-remove-nix-mineral-add-nixsecauditor-design.md`.
NixSecAuditor stays: it is an eval-time *auditor* that warns, while nix-mineral is a
runtime *enforcer* that changes configuration. They are complementary, not
alternatives.

## Why the previous attempt failed

nix-mineral was dropped because it "historically broke things" and had sat at
`enable = false`. `git log -S nix-mineral -- hosts/deadPc/config.nix` shows the old
block carried four fixes that were written but left commented out:

```nix
# system.multilib = true;
# system.yama = "relaxed";
# filesystems.normal."/home".options."noexec" = false;
# filesystems.normal."/tmp".options."noexec" = false;
```

Those four are the whole of the historical breakage — 32-bit applications (which
also forced the since-removed `alsa.support32Bit = lib.mkForce false` hack),
debuggers, and executables under `/home` and `/tmp` such as the `python-auto-type`
project's `code/` directory.

Upstream has since been rewritten into a `nix-mineral.settings.*` option tree with
stackable presets. Its `compatibility` preset applies all four fixes plus several
more (`/var/lib` exec, `hidepid` off on `/proc`, `binfmt_misc` on). That preset is
the foundation of this design.

## Threat model, stated honestly

The stated motivation is running AI coding agents more safely. nix-mineral does
**not** address that. It hardens the kernel, network stack, mount options and PAM;
an agent running as `deadmade` already holds that user's full rights — the repos,
the SSH keys, the sops age key — without touching anything nix-mineral protects.
Upstream's own documentation notes that `noexec` is "trivially bypassable through
the use of interpreters, such as `python3`", which is an agent's normal mode of
operation.

nix-mineral is worth having as a baseline against kernel exploits and local
privilege escalation. Agent confinement is a separate problem needing a separate
design, and is explicitly out of scope here.

## Architecture

Three files. One is new.

### `flake.nix` — add the input

```nix
nix-mineral = {
  type = "github";
  owner = "cynicsketch";
  repo = "nix-mineral";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

The `follows` is safe: upstream's own flake already tracks `nixos-26.05`, matching
this repo's `nixpkgs`.

### `modules/nixos/hardening/nix-mineral.nix` — new module

A new `hardening` domain rather than `core`. `profiles/nixos/core.nix` imports the
core domain via `builtins.attrValues`, so a module placed there would silently apply
to deadWsl, deadPi and deadServer on their next rebuild. nix-mineral's bind-mount and
`/boot` hardening assumes a conventional partition layout; on WSL and the Pi's SD
image that risks an unbootable system. Nothing imports a `hardening` domain via
`attrValues`, so it cannot leak.

`flake/lib/registry.nix` only sees git-tracked files, so the new file must be
`git add`ed before it will evaluate.

### `hosts/deadPc/config.nix` — one import

Add `outputs.nixosModules.hardening.nix-mineral` to `imports`, beside the existing
`outputs.nixosModules.virtualization.vmware`.

### `CLAUDE.md` — restore the reboot note

The 2026-08-01 removal deleted the `nixos-rebuild boot` guidance. nix-mineral changes
kernel parameters and mount options, which only take effect on reboot, so that note
becomes relevant again.

## The module

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
        # This host needs them: hardware.graphics.enable32Bit is on for Wine,
        # and desktop/base.nix sets services.pipewire.alsa.support32Bit.
        # The compatibility preset sets this too; stated explicitly because
        # this is the regression that forced the old alsa.support32Bit
        # mkForce hack.
        multilib = true;
      };
    };
  };
}
```

Settings written directly sit at normal priority (100) and beat presets, which
upstream applies at `mkOverride 800`. So every value above wins cleanly over
`compatibility`.

### Decisions embedded above

**`/home` stays executable.** Measurement of the live host found executables spread
across ~28 locations: `.local/share` (2550), `.claude-science/conda` (1725),
`.nuget/packages` (953), `Lingua-Serpentis/target` (683), `Motrix/node_modules`
(179), `tuitr/target` (121), `python-auto-type/code` (28), `.venv` in three projects,
`.direnv` in seventeen, plus `.cargo`, `.npm`, `.config/opencode` and `.vscode-oss`.
Because the ~18 project directories sit directly in `$HOME`, keeping `noexec` would
need ~28 `exec` bind mounts, one more per new clone, each a boot-time failure if its
directory is ever deleted or renamed. Deferred until projects are consolidated under
a single `~/dev` tree, at which point the exclusion list drops to about eleven
entries and this decision should be revisited.

**The `performance` preset is not used**, despite the requirement to keep full CPU
speed. It bundles `pti = false` and `iommu-passthrough = true`, weakening
Meltdown/KASLR and DMA-attack protection respectively for no gain on an x86_64
desktop — `iommu.passthrough` is an ARM64 I/O optimisation, and AMD Zen does not use
PTI anyway. Setting `cpu-mitigations` and `slab-debug` directly delivers the entire
speed benefit without that cost.

**`yama` is left alone.** deadPc already runs `ptrace_scope=1`, and the compatibility
preset's `relaxed` is the same value, so debugging behaviour is unchanged. Attaching
to an unrelated running process already requires `sudo` today and still will.

**`ip-forwarding` is left at its default.** `net.ipv4.ip_forward` is already `0` on
this host and podman works, because netavark raises it at container start.

**`io_uring` stays disabled**, per requirements — it is not used here.

## Verified non-issues

- `lockdown` and `only-signed-modules` are deprecated upstream and are no-ops on
  NixOS kernels, so the proprietary nvidia driver and VMware's out-of-tree `vmmon`
  and `vmnet` modules are unaffected.
- The Kicksecure module blacklist does not contain `vmmon`, `vmnet`, `kvm` or
  `squashfs`; VMware Workstation, KVM, flatpak and AppImages are unaffected.
- `usbguard` lives under `extras` and is off by default.
- deadPc is a single ext4 `/` with a separate vfat `/boot` — exactly the layout
  nix-mineral's bind-mount hardening assumes, so no btrfs-subvolume footguns.
- `unprivileged_bpf_disabled` is already `2` on this host, stricter than
  nix-mineral's `1`, so eBPF tooling is already root-only and does not regress.

## Residual risks

`etc.kicksecure-module-blacklist` stays enabled. Two entries could matter:

1. **`nfs*`, `cifs`, `ksmbd`.** deadPi runs a Samba server. Browsing those shares via
   GVFS or Dolphin uses userspace `libsmbclient` and is unaffected; only a literal
   `mount -t cifs` breaks.
2. **`gnss*`, `garmin_gps`, `can*`.** Flagged because `chiplang-nix` ships
   `depthfinder`/`dfn-mounter` and the host has MNT Reform keyboard firmware repos.
   If either talks to GPS or CAN hardware, the blacklist will stop it.

Escape hatch for both: `nix-mineral.settings.etc.kicksecure-module-blacklist = false`,
or keep the blacklist and add a targeted `boot.kernelModules` entry.

## What this gains over the current configuration

Network hardening (`rp_filter`, syncookies, RFC1337, source-route and redirect
rejection, IPv6 privacy addressing); the Kicksecure module blacklist; `nosuid` and
`nodev` on `/home` and `/tmp`; hardened `/boot` permissions; `noexec` on `/root`,
`/var`, `/var/tmp` and `/var/log`; SUID, link and file protections; PAM shadow
hashing and login fail delay; entropy hardening; and kernel sysctls including
`kexec` disabled, `sysrq` restricted, TIOCSTI blocked, `io_uring` off, BPF JIT
hardening, kstack offset randomisation, slab merging off and `vsyscall` off.

## Verification

Changes to kernel parameters and mounts require a reboot, so verification follows
`nos` **and a reboot**. Rollback is selecting the previous GRUB generation.

1. `nix flake check` and
   `nix build .#nixosConfigurations.deadPc.config.system.build.toplevel` evaluate.
2. A second host still evaluates unchanged, confirming no leak:
   `nix build .#nixosConfigurations.deadServer.config.system.build.toplevel --dry-run`.
3. `nproc` reports **24** — SMT preserved.
4. Run a binary from a project `.venv` and from `Lingua-Serpentis/target`, plus
   `python-auto-type/code` — the original regression.
5. `podman run --rm alpine ping -c1 1.1.1.1` — container networking.
6. `nix build .#nixosConfigurations.deadPi.config.system.build.toplevel --dry-run` —
   exercises the aarch64 `binfmt_misc` path.
7. `grep -o 'ia32_emulation=[0-9]' /proc/cmdline` returns nothing, confirming 32-bit
   support survived; audio and a 32-bit Wine application still work.
8. `sysctl kernel.yama.ptrace_scope kernel.perf_event_paranoid` returns `1` and `2`,
   unchanged from before.
9. VMware Workstation starts and `lsmod | grep -E 'vmmon|vmnet'` shows both loaded.

## Out of scope

- Agent confinement (sandboxing what an AI agent can read and write). Separate spec.
- Consolidating project directories under `~/dev`, and the `noexec` on `/home` that
  it would unlock. Separate work, tracked for later.
- Enabling nix-mineral on any host other than deadPc.
