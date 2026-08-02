# Design: deploy deadPi from deadPc with deploy-rs

Date: 2026-08-02
Status: approved, ready for implementation planning

## Problem

`deadPi` is a headless Raspberry Pi 4 that currently updates itself: you SSH
in and run `nixos-rebuild`/`nh` on the Pi, which evaluates and builds the whole
closure on the Pi's own CPU. That is slow, and it means every update requires
an interactive session on the target.

`deadPc` is already equipped to build for it. `hosts/deadPc/config.nix:21`
sets `boot.binfmt.emulatedSystems = ["aarch64-linux" "riscv64-linux"]` and
`:27` feeds that into `nix.settings.extra-platforms`, so deadPc can already
build `aarch64-linux` derivations. Nothing consumes that capability.

## Goal

Build `deadPi`'s system closure on deadPc and push it to the Pi with one
command, with automatic rollback if the deployment breaks the machine.

Explicit non-goal: unattended/scheduled updating. This design produces a
push-button deploy, not a timer.

## Approach

Use [deploy-rs](https://github.com/serokell/deploy-rs). It builds locally,
`nix copy`s the closure to the target, activates it over SSH, and — via
`magicRollback` — requires a confirmation over a *fresh* SSH connection after
activation. If the machine stops answering, it reverts to the previous
generation on its own. For a headless box in a cupboard, that property is the
whole reason to prefer it over plain `nixos-rebuild --target-host`, which
would also work but leaves you walking over with a keyboard.

### Why not the alternatives

- **`nh os switch . -H deadPi --target-host`** — the installed `nh` (4.4.2)
  supports `--target-host`/`--build-host`, as does the `nixos-rebuild-ng` in
  this generation. Zero new inputs, but no rollback safety net.
- **colmena** — better once several hosts deploy together; more upfront
  restructuring than this job needs.
- **`system.autoUpgrade` / comin** — pull-based and genuinely unattended, but
  needs a build story (deadPc as remote builder, or a harmonia cache) and is
  additive on top of this design rather than an alternative to it.

## Verified facts

Everything below was checked rather than assumed.

| Claim | How verified |
| --- | --- |
| Pi is reachable at `10.10.10.137`, sshd answers | `ping`, `ssh` handshake |
| Key auth fails today for `admin`, `nixos`, `root`, `deadmade` | all four return `Permission denied (publickey,password,keyboard-interactive)` |
| `admin` is in `nix.settings.trusted-users` | `hosts/deadPi/default.nix:142` — required for `nix copy` from deadPc to be accepted |
| flake-parts accepts a custom `flake.deploy` output | minimal test flake set `flake.deploy.nodes.demo.hostname`; `nix eval` returned it |
| `activate.nixos base` uses `base.config.system.build.toplevel` and runs `switch-to-configuration switch` | deploy-rs `flake.nix:94` |
| The activate wrapper embeds `${deploy-rs}/bin/activate` **for the target system** | deploy-rs `flake.nix`, `custom.__functor` — implies an aarch64 deploy-rs build is needed |
| Node schema: `hostname` required; profile schema: `path` required | deploy-rs `interface.json` |
| Valid per-node settings: `sshUser`, `user`, `sshOpts`, `groups`, `fastConnection`, `autoRollback`, `magicRollback`, `confirmTimeout`, `activationTimeout`, `tempPath`, `interactiveSudo` | deploy-rs `interface.json`; `sudo` and `remoteBuild` also exist in `src/data.rs` though absent from the schema |
| `--dry-activate` is supported | deploy-rs `flake.nix` defines `dryActivate`/`boot`/`test` variants |

Not yet verified, so step 1 checks it: passwordless sudo for `wheel` on the
Pi. It is inferred from `profiles/installation-device.nix` setting
`security.sudo.wheelNeedsPassword = mkImageMediaOverride false`, which
`hosts/deadPi/default.nix` does not override. If it turns out false, the
fallback is `interactiveSudo = true` on the node.

## Build cost and the kernel

All narinfo lookups below were made against `https://cache.nixos.org`.

| Derivation | Result |
| --- | --- |
| `linux-rpi-6.18.34-stable_20260609` (the kernel `nixos-hardware` pins) | HTTP 404 |
| aarch64 `deploy-rs` build | HTTP 404 |
| `linux-rpi-6.12.75-1+rpt1` (nixpkgs 26.05's own `linux_rpi4`) | HTTP 404 |
| `linux-rpi-6.12.47-stable_20250916` (what the Pi runs today) | HTTP 200 |
| mainline `linuxPackages` 6.18.40 | HTTP 200 |
| mainline `linuxPackages_6_12` 6.12.97 | HTTP 200 |
| mainline `linuxPackages_latest` 7.1.5 | HTTP 200 |

An attempt to build the closure ran 1h20m on 24 cores without finishing and
was abandoned. This kernel cost is additive to the deploy-rs Rust build cost
noted in the `flake.nix` section below.

`nixos-hardware`'s `raspberry-pi/common/kernel.nix` calls nixpkgs' `buildLinux`
with a pinned `tag`/`hash` of the `raspberrypi/linux` fork. A cache hit
therefore depends on that pin matching a derivation Hydra happened to build —
an alignment, not a guarantee, and one that is currently broken.

Three options would make a deploy feasible, stated neutrally:

1. `remoteBuild = true` on the deploy node (deploy-rs supports it) — the Pi
   builds natively; slow but bounded, and needs no cross-compilation.
2. Override the kernel to a cached mainline one. `nixos-hardware` sets
   `boot.kernelPackages` with `lib.mkDefault`, so a plain assignment in
   `hosts/deadPi/default.nix` overrides it with no `mkForce` needed.
   `linuxPackages_6_12` (6.12.97) is the smallest jump from the Pi's current
   6.12.47. Tradeoff: loses Raspberry Pi Foundation patches (camera/unicam,
   hardware codecs, some device-tree overlays).
3. A remote builder or binary cache serving aarch64.

**Decision: option 2.** `hosts/deadPi/default.nix` sets
`boot.kernelPackages = pkgs.linuxPackages_6_12;`. Measured effect on
`nix build --dry-run .#deploy.nodes.deadPi.profiles.system.path`:

| | Before | After |
| --- | --- | --- |
| Derivations to build | 68 | 67 |
| Kernel *compiled* | yes — `linux-rpi-6.18.34` | no, substituted |

The derivation count barely moves because the count was never the point: the
one derivation that disappeared was the multi-hour one. What remains on the
kernel side (`linux-6.12.97-modules`, `-modules-shrunk`, `initrd-*`,
`dtbs-filtered`) is `aggregateModules` and friends — symlink joins and
`depmod`, measured at **1.4 seconds** for the aggregate.

The dominant remaining cost is the ~55 Rust crates that build the aarch64
`deploy-rs` binary. That is unavoidable under any of the three options,
because `activate.nixos` embeds the deploy-rs binary for the *target* system.
Only dropping `inputs.nixpkgs.follows` (see the `flake.nix` section) could
make it substitutable, at the cost of a second nixpkgs in the lock.

## Architecture

`deploy.nodes.*` is a **flake output**, evaluated on deadPc. It therefore
cannot be set from `hosts/deadPi/default.nix`, which is a NixOS module.

The per-host data still lives with the host. `hosts/hosts.nix` maps
`deadPi → nixosModules = [./deadPi]`, which imports the *directory* and so
only ever evaluates `default.nix`. A sibling file is invisible to the NixOS
evaluation and free for the flake to read:

```
hosts/deadPi/
  default.nix    # NixOS module — unchanged by this design
  deploy.nix     # plain attrset consumed by flake/modules/deploy.nix
```

This mirrors the layout the since-removed `hosts/deadPc/sops.nix` used, keeps
`hosts/hosts.nix` untouched, and extends to `deadServer` later by adding one
file.

## Files

### `flake.nix` — new input

Structured style, matching every other input in the file:

```nix
deploy-rs = {
  type = "github";
  owner = "serokell";
  repo = "deploy-rs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`follows = "nixpkgs"` is chosen for consistency with the rest of the flake,
at a known cost: deploy-rs then builds against the 26.05 pin rather than its
own, so it will **not** hit deploy-rs's cachix. Because `activate.nixos`
embeds the deploy-rs binary for the *target* system, that means one
qemu-emulated aarch64 Rust build on deadPc, expected in the 5–15 minute range,
once. Dropping the `follows` would likely substitute instead, at the cost of a
second nixpkgs in the lock.

### `hosts/deadPi/deploy.nix` — new

```nix
{
  hostname = "10.10.10.137";
  sshUser = "admin";
  user = "root";
  # SD-card-backed Pi doing a release upgrade can exceed deploy-rs's defaults;
  # a timeout here would trigger a spurious rollback mid-activation.
  activationTimeout = 1200;
  confirmTimeout = 120;
  magicRollback = true;
  autoRollback = true;
}
```

The two timeouts override deploy-rs's defaults of 240s and 30s. Those defaults
assume activation is quick; on this target the first deploy is a release
upgrade with a kernel change, written to an SD card. If `switch-to-configuration
switch` runs past `activationTimeout`, no confirmation reaches the deploying
host inside `confirmTimeout` and magic-rollback reverts a system that was
activating correctly — discarding the build and leaving a headless machine
mid-switch. Raising them trades a longer worst-case hang for not throwing away
a good deploy.

### `flake/modules/deploy.nix` — new, imported from `flake.nix`

Discovers `hosts/*/deploy.nix`, and for each builds a node whose system
profile is that host's activation package. The target system string comes from
the matching `hostDefinitions` entry, so `aarch64-linux` is not hardcoded.

```nix
profiles.system.path =
  inputs.deploy-rs.lib.${hostConfig.system}.activate.nixos
    config.flake.nixosConfigurations.${name};
```

Referencing `config.flake.nixosConfigurations` rather than `self` is the
flake-parts idiom and avoids self-reference during evaluation.

The same module defines `perSystem.apps.deploy` pointing at the pinned
`inputs.deploy-rs`, so the alias runs the locked version instead of refetching
or drifting against the schema of a different build.

### `modules/home-manager/core/aliases.nix`

```nix
nospi = "nix run .#deploy -- .#deadPi";
```

alongside the existing `nos`/`nhs`/`nosf`/`nhsf` at lines 3–6.

### `hosts/deadPi/default.nix`

Add `users.users.admin.openssh.authorizedKeys.keys` with deadmade's ed25519
public key. This is the only change to the Pi's system config, and it is
deliberately the *first* thing deployed rather than a prerequisite.

## Rollout order

Each step is independently verifiable. Nothing before step 4 can affect the Pi.

1. `ssh-copy-id admin@10.10.10.137` — uses the password auth that already
   works. Verify with `ssh admin@10.10.10.137 sudo -n true`; a clean exit
   confirms the passwordless-sudo assumption above.
2. `nix build .#nixosConfigurations.deadPi.config.system.build.toplevel` on
   deadPc. Proves emulated aarch64 building works end to end with the Pi not
   involved.
3. Wire up the flake. Verify with `nix flake check` and
   `nix eval .#deploy.nodes.deadPi.hostname`. `flake.deploy` is a non-standard
   output, so `nix flake check` will emit an informational warning for it,
   exactly as it already does for `nixosProfiles` and `homeManagerModules`.
4. `nix run .#deploy -- --dry-activate .#deadPi`, then the same without
   `--dry-activate`. **This first deploy is not a no-op**: the Pi runs NixOS
   25.11 with kernel 6.12.47, while this repo targets 26.05 with kernel
   6.18.34, so the first real deploy is a full release upgrade plus a
   six-minor-version kernel jump — not a byte-identical closure. The
   transport-only test is `--dry-activate` itself, which genuinely exercises
   build, copy, SSH and sudo without changing the running system. Note also
   that `magicRollback` only protects against losing SSH after activation; it
   does not protect against a system that activates successfully and then
   fails to boot, which matters here because a kernel change rewrites the
   extlinux config, and selecting an older generation on a headless Pi
   requires a screen or serial console.
5. Commit the `authorizedKeys` change and deploy it. This is the first
   deployment that changes anything, and it runs with rollback already proven.

## Failure handling

- `autoRollback` reverts if the activation script itself fails.
- `magicRollback` reverts if the Pi stops answering SSH after activation.
- Password authentication stays enabled on the Pi throughout, so a botched key
  change cannot lock you out.
- Escape hatch of last resort: `nixosConfigurations.deadPi` still builds an SD
  image, so a card can be flashed from a known-good revision.

## Out of scope

- **Splitting the sd-image installer out of `nixosConfigurations.deadPi`.**
  `hosts/hosts.nix` sets `useSdImageInstaller = true`, so the config pulls in
  `sd-image-aarch64-installer.nix`, which is where the Pi's sshd, its
  passwordless sudo, its `fileSystems."/"` (`by-label/NIXOS_SD`) and
  `/boot/firmware` definitions, and a full pinned copy of nixpkgs
  (`cd-dvd/channel.nix`) come from. None of that obstructs deploying —
  `sdImage.*` is only evaluated if something asks for
  `config.system.build.sdImage`, and `toplevel` never does. Splitting it is a
  boot-path refactor on a headless machine and is strictly safer to attempt
  *after* rollback protection exists. Its only real payoff is reclaiming the
  space that pinned nixpkgs copy occupies on the SD card.
- `deployChecks` integration with `nix flake check` — this is true of
  `deploy-activate`, which would build the Pi's full closure on every check,
  but not of `deploy-schema`, which only builds `check-jsonschema` plus a
  `writeText` of `builtins.toJSON deploy` — no closure realisation. Adding it
  would buy little regardless: neither `generic_settings` nor
  `profile_settings` sets `additionalProperties: false` in deploy-rs's
  `interface.json`, and its Rust structs have no `deny_unknown_fields`, so a
  misspelled setting like `magicRollBack` is silently dropped by both layers
  anyway.
- Unattended or scheduled deployment.

## Related finding: credentials in a public repo

Found while scoping this; **not addressed by this design**, recorded so it is
not lost.

`hosts/deadPi/default.nix:132` and `:139` contain the same yescrypt
`hashedPassword` for the `nixos` and `admin` accounts, both of which are in
`wheel` with passwordless sudo. `gh repo view` confirms
`deadmade/nix-configuration` is `"visibility":"PUBLIC"`, and the hash is
present in git history back through `0238c21`, so removing it now would not
unpublish it. The password needs rotating, not merely encrypting.

sops-nix is **not** available to fix this today: it was removed in `5665c51`
("chore: remove sops-nix and arion container stack") along with `.sops.yaml`,
`secrets/`, and the three `hosts/*/sops.nix`. `CLAUDE.md`'s "Secrets" section
still describes it as present and should be corrected.

Note also that sops could not have hidden the deploy configuration even if it
were present: it decrypts at *activation* time on the target, into
`/run/secrets`, whereas `deploy.nodes.deadPi.hostname` is needed at
*evaluation* time on deadPc. Different layer. Separately, `10.10.10.137` is an
RFC1918 address that already appears in the public repo at
`hosts/deadPi/default.nix:105` as the restic `listenAddress`; if it should be
kept out of the repo anyway, a `~/.ssh/config` alias achieves that for free,
since deploy-rs resolves `hostname` through `ssh`.

The correct fix — reintroducing sops-nix, deriving the Pi's age key from its
SSH host key, and moving both accounts to `hashedPasswordFile` with
`sops.secrets.<name>.neededForUsers = true` (the flag that decrypts into
`/run/secrets-for-users` *before* the user-creation activation script, which
`users.mutableUsers = true` otherwise races) — is its own spec.
