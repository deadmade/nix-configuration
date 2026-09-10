# nix-secrets as the secret manager

**Date:** 2026-08-18
**Status:** Design approved, pending implementation plan

## Context

This flake has no secret manager today. `CLAUDE.md` documents a `sops-nix` setup —
`secrets/`, `.sops.yaml`, `hosts/deadPc/sops.nix`, an age key at
`~/.config/sops/age/keys.txt` — but none of those files exist and `sops-nix` is not a
flake input. That section is aspirational and must be rewritten as part of this work.

We are adopting [`nix-secrets`](https://github.com/unnamed-systems/nix-secrets) rather
than sops-nix or agenix. It comes from the same authors as `nixsecauditor`, which this
flake already runs (`modules/nixos/core/nixsecauditor.nix`), is age-based, declares
everything inside the NixOS module system with no sidecar config file, and ships a
~2 MB Rust CLI instead of the ~50 MB `sops` binary.

### Driving requirements

1. A declarative password hash for `deadmade`, replacing today's imperative `passwd`.
2. A GitHub token available to `gh`, `git`, and the Nix daemon without an interactive
   login on each host — one credential shared across hosts, not one per host.
3. Room to grow into service credentials on `deadServer` and `deadPi` later.

### Non-goals

- Secret **generators**. The upstream README states generators are feature-incomplete.
  We use none.
- Home Manager secret management. `nix-secrets` is NixOS-only; there is no Home Manager
  module. Home Manager consumes secrets as literal `/run/nix-secrets/...` path strings.
- Migrating anything. There is nothing to migrate from.
- Post-quantum recipients. Would require the `age` package plus `age-plugin-pq`; no need.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Storage location | `secrets/` in this public repo | Age ciphertext is safe to publish; private keys never enter git. One edit loop, no SSH auth on any host, CI and deploy-rs unaffected. A private storage repo would hide only the *filenames* while costing SSH read access on every host and a `flake.lock` bump per secret change. |
| Key model | Per-host key + a personal master key | Each host holds only its own identity; no key ever travels between machines. The master key sits in `defaultRecipients` so secrets can always be read and rekeyed from `deadPc`, which is what makes adding a host possible later. |
| Module placement | `modules/nixos/core/nixSecrets.nix` | Auto-discovered by `flake/lib/registry.nix` and auto-imported by `profiles/nixos/core.nix` (`builtins.attrValues outputs.nixosModules.core`), so shared config reaches all five hosts with no per-host import boilerplate. |
| Rollout gate | The shared module does **not** set `enable` | Each host opts in with `security.nix-secrets.enable = true;` once its key exists. Un-keyed hosts are wholly unaffected, so the rollout is incremental rather than all-five-at-once. |

Rejected: a new `modules/nixos/security/` domain with explicit per-host imports — more
boilerplate, and it would sit confusingly parallel to the existing
`modules/nixos/core/security.nix`.

## How it works

Two independent decryption paths. Under both, the private key lives only on local disk
and is never committed.

**Activation (automatic, per machine).** `secrets/*.enc` ride into `/nix/store` as part
of the system closure. An activation script runs
`nix-secrets activate <manifest.json>`, which looks for a private key at each path in
`identityPaths` on that machine, decrypts each secret, and writes the plaintext to
`/run/nix-secrets/<name>` — tmpfs, so RAM-only and gone on reboot — with the declared
`owner`/`group`/`mode`. Secrets marked `neededForUsers` are written to
`/run/nix-secrets-for-users/<name>` by a second activation script ordered *before* user
creation.

**Editing (manual, on deadPc).** `nix-secrets edit <name>` evaluates
`.#nixosConfigurations.<host>.security.nix-secrets.manifest`, decrypts the `.enc` with
the master key, opens `$EDITOR` on a temp file, and re-encrypts to every recipient on
save. `nix-secrets rekey` re-encrypts after a recipient list changes.

An age file is encrypted to **many recipients at once**; any single matching private key
opens it. So one `github/token.enc` yields the same token value on every host, each host
using its own key.

**Building never decrypts.** A build only moves ciphertext into the store and writes the
activation script. `nix flake check`, `nixos-rebuild build`, and deploy-rs building
deadPi's closure on deadPc all work on a machine holding no keys at all.

## Architecture

### `modules/nixos/core/nixSecrets.nix` (new)

Shared infrastructure for all hosts. Sets no `enable`.

```nix
{inputs, vars, ...}: {
  imports = [inputs.nix-secrets.nixosModules.default];

  security.nix-secrets = {
    storage = ../../../secrets;
    storagePath = "/home/${vars.username}/nix-configuration/secrets";

    identityPaths = [
      "/var/lib/nix-secrets/identity.txt"                     # this host's key
      "/home/${vars.username}/.config/nix-secrets/keys.txt"   # master key (deadPc only)
    ];

    recipientAliases = {
      master = "age1...";          # personal key, backed up offline
      deadPc = "age1...";
      deadConvertible = "age1...";
      deadServer = "age1...";
      deadPi = "age1...";
      deadWsl = "age1...";
    };

    defaultRecipients = ["master"];
  };
}
```

Listing the master key path on every host is safe: `get_identities` filters with
`path.is_file()` (`src/utils/age.rs:32`), so a non-existent identity path is silently
skipped rather than an error.

`storagePath` only supplies the CLI's default `--storage`; it is harmless on headless
hosts where the repo lives elsewhere and the CLI is never run.

Aliases are populated incrementally — a host's entry is added when its key is generated,
not upfront.

### Shared secret declarations live with the shared module, not per host

A secret name maps to exactly **one** file in storage: `github/token` is always
`secrets/github/token.enc`. That single file is encrypted to one recipient list. If each
host declared `"github/token"` with its own `recipients`, the lists would silently
diverge, and `nix-secrets rekey` — which evaluates a *single* host's manifest — would
re-encrypt the shared file to only that host's recipients, locking every other host out
at its next activation.

So **secrets shared across hosts are declared once**, in the same module as the
infrastructure, with a recipient list covering every host that will ever be enabled:

```nix
  security.nix-secrets.secrets = {
    "github/token" = {
      recipients = ["deadPc" "deadConvertible"];
      owner = vars.username;
      mode = "0400";
    };

    password.neededForUsers = true;        # recipients from defaultRecipients + below
    root-password.neededForUsers = true;
  };
```

These declarations are inert on hosts that never set `enable`, so carrying them in the
core module costs nothing on deadPi, deadServer, or deadWsl.

The corollary is a rule to hold onto: **when a host is enabled, it must already appear in
the recipient list of every shared secret**, or its activation fails on the secret it
cannot decrypt. Adding a host is therefore always: add alias → add to recipient lists →
`rekey` → commit → enable.

### `hosts/<name>/secrets.nix` (new, per host)

Only the opt-in and genuinely host-local wiring. Imported from the host's `config.nix`,
mirroring the `hosts/deadPc/sops.nix` pattern `CLAUDE.md` already describes.

```nix
{config, vars, ...}: {
  security.nix-secrets.enable = true;

  users.mutableUsers = false;
  users.users.${vars.username}.hashedPasswordFile =
    config.security.nix-secrets.secrets.password.path;
  users.users.root.hashedPasswordFile =
    config.security.nix-secrets.secrets.root-password.path;
}
```

The password wiring **must** be per-host, not in `modules/nixos/core/user.nix`. That file
is auto-imported by every host, so `mutableUsers = false` there would lock the accounts on
deadServer, deadPi, and deadWsl, none of which have a password secret.

### `secrets/` (new)

Encrypted files, named by secret: `github/token` lives at `secrets/github/token.enc`.
Must be `git add`ed — untracked files are invisible to flake evaluation.

### Local state, never committed

- `/var/lib/nix-secrets/identity.txt` — the host key, mode `0400`, root-owned. The
  `compatibility` preset of nix-mineral on deadPc does not apply `noexec`/restrictions to
  `/var/lib`, so this location is fine there.
- `~/.config/nix-secrets/keys.txt` — the master key on deadPc. **Back this up offline
  (password manager plus an offline copy).** If every copy is lost, every secret is
  permanently unrecoverable.

## Rollout

Ordered so the riskiest step runs on a proven mechanism. **The implementation plan covers
Phases 1-3.** Phase 4 is recorded here as forward-looking notes only and gets its own
plan when there are real service credentials to store.

### Phase 1 — Plumbing on deadPc, piloted with the GitHub token

Add the flake input, the shared module, deadPc's `secrets.nix`, generate deadPc's host
key and the master key, and get `github/token` decrypting to `/run/nix-secrets`.

The GitHub token is the pilot rather than the password because a broken token costs a
`gh auth login`, whereas a broken password can lock the account (see Phase 2).

Consumers, all of which take a literal path string since Home Manager cannot read
`config.security.nix-secrets`:

- **`gh`** — `programs.gh.enable` stores its token imperatively in
  `~/.config/gh/hosts.yml`. Instead export the token from zsh:
  `export GH_TOKEN="$(cat /run/nix-secrets/github/token 2>/dev/null)"`, guarded so a
  missing file does not produce a shell error.
- **`git`** — nothing to write. `programs.gh.enable` is already set in
  `modules/home-manager/core/git.nix`, and `programs.gh.gitCredentialHelper.enable`
  defaults to `true`, so Home Manager already routes `github.com` credentials through
  `gh auth git-credential` (verified in the pinned home-manager's
  `modules/programs/gh.nix:189-201`). `gh` picks up `GH_TOKEN` from the environment, so
  the zsh export covers both tools. Caveat: this only applies to git invoked from an
  interactive shell — a systemd unit would not see `GH_TOKEN`.
- **Nix daemon** — a `nix-secrets` **template**, not a second secret, so the token is
  stored once:

  ```nix
  security.nix-secrets.templates.nixAccessTokens.content = ''
    access-tokens = github.com=${config.security.nix-secrets.secrets."github/token"}
  '';
  ```

  Templates default to `/run/nix-secrets/templates/<name>`, mode `0400`, owner and group
  `0` — exactly right for the daemon. Pull it in with
  `nix.extraOptions = "!include ${config.security.nix-secrets.templates.nixAccessTokens.path}";`.
  Verified against `man 5 nix.conf`: a missing file is an error for `include` but
  **ignored** for `!include`, so this cannot break `nix` on a host where the template is
  absent.

### Phase 2 — Declarative password on deadPc

**This phase carries a real lockout risk and must be executed with the safety net below.**

Verified from `nixpkgs` `nixos/modules/config/update-users-groups.pl`:

- `:241-246` — `hashedPasswordFile` is read into `hashedPassword`; a missing file only
  emits a warning.
- `:299-300` — for a user **already present in `/etc/shadow`**, the declarative hash is
  applied only when `mutableUsers = false`.
- `:306-311` — for a **brand-new** user, the hash is applied regardless.

`deadmade` already exists in `/etc/shadow` and `users.mutableUsers` is at its default
`true`. **Consequence: setting `hashedPasswordFile` alone would be silently ignored.**
Declarative passwords require `users.mutableUsers = false`.

That is what creates the risk. With `mutableUsers = false`, `:299` writes `!` — a locked
account — whenever `hashedPassword` is undefined, which is exactly what happens if the
secret fails to decrypt. Worse, `/etc/shadow` is imperative state: rolling back to a
generation with `mutableUsers = true` does **not** restore the old hash, because `:299`
and `:300` do not fire and the existing `!` is preserved. A bad switch therefore survives
a generation rollback, and recovery would need `init=/bin/sh` or live media.

Mitigations, all required:

1. **Verify before flipping.** Split this into two commits. The first declares the
   `password` secret with `neededForUsers = true` *and* sets
   `users.users.${vars.username}.hashedPasswordFile`, while leaving `mutableUsers` at
   `true` — the option is inert in that state, so this switch cannot change `/etc/shadow`.
   Confirm `/run/nix-secrets-for-users/password` exists and holds a valid `$y$`/`$6$`
   hash. Only the second commit sets `users.mutableUsers = false`.
2. **Keep a root shell open.** Hold `sudo -i` on a second TTY across the second switch so
   `passwd` recovery is possible without rebooting.
3. **Declare a root fallback in the `mutableUsers = false` commit.** With `mutableUsers`
   off, every unspecified account is locked to `!`, root included. Give root its own
   `hashedPasswordFile` — a second `neededForUsers` secret, verified the same way — so a
   failure on `deadmade` still leaves a console login.
4. Generate hashes with `mkpasswd -s`.

`neededForUsers` secrets cannot set `owner` or `group`, and resolve under
`/run/nix-secrets-for-users/`. Wire the user in `hosts/deadPc/secrets.nix` — **not** in
`modules/nixos/core/user.nix`, which every host imports. The stale "set a password with
`passwd`" comment at `modules/nixos/core/user.nix:8` should be updated to point at the
per-host file.

Because deadPc runs nix-mineral, follow the existing repo guidance and prefer
`nixos-rebuild boot` + reboot for hardening-adjacent changes — but note that for *this*
step the open root shell, not the bootable prior generation, is the actual safety net,
since `/etc/shadow` changes persist across generations.

### Phase 3 — deadConvertible

Generate its host key, add its alias, add it to the shared secrets' recipient lists,
`rekey` from deadPc, commit, **then** enable — in that order, since an enabled host that
is not yet a recipient fails activation. No new mechanism.

### Phase 4 — deadServer and deadPi

Deferred until there are real service credentials to store. Notes for then:

- `nix-secrets` is **not** in nixpkgs (verified), so it builds from source with no binary
  cache. On deadPi that means an aarch64 Rust build — native on the Pi, or emulated on
  deadPc via the existing `boot.binfmt.emulatedSystems`. Check build cost before
  committing, consistent with the standing practice of checking cache coverage for deadPi.
- deadPi deploys via deploy-rs. Building on deadPc stays keyless; the Pi decrypts at
  activation using its own key.
- `deadWsl` is left out entirely for now — no secret need, and a WSL user password is
  meaningless.

## Verification

- `nix flake check` after adding the input and module (custom-output warnings are
  expected and pre-existing).
- **`nixos-rebuild dry-activate` is the pre-flight gate for every phase.** Verified in
  `src/command/activate.rs:42,239-256`: dry mode decrypts every secret and template — so
  it proves keys, ciphertext, and recipient lists are all correct — but skips linking them
  into their final paths, and does not run user/group updates. Run it before every real
  switch in Phases 2 and 3.
- **A declared secret whose `.enc` file is missing makes the switch fail**, not warn:
  `InputReader::new` errors and the result is collected with `?`
  (`src/command/activate.rs:88-99`). So a secret must be *created* before the first switch
  that declares it. The CLI is available without a rebuild via
  `nix build --no-link --print-out-paths
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package`.
- Phase 1: `nix-secrets edit github/token` round-trips; after switch,
  `/run/nix-secrets/github/token` exists with the declared owner and mode;
  `gh auth status` and `git ls-remote` on a private repo succeed; `nix` still runs with
  the `!include` line present.
- Phase 2: `/run/nix-secrets-for-users/password` holds a valid hash *before* the
  `mutableUsers` flip; after the switch, `sudo grep deadmade /etc/shadow` shows that hash
  rather than `!`; login on a fresh TTY succeeds while the root shell is still open.
- Phase 3: the same secret decrypts to the identical value on both hosts.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Password lockout that survives generation rollback | High | The four mitigations in Phase 2; ordering the token pilot first |
| Master key loss makes all secrets unrecoverable | High | Offline backup at creation time, before any secret exists |
| `nix-secrets` maturity — upstream calls it "late development stage", 26 stars | Medium | Use no generators; same authors as the already-trusted `nixsecauditor`; the pilot secret is low-consequence |
| Not in nixpkgs, so built from source uncached | Low | Small crate; matters mainly for aarch64/deadPi in Phase 4 |
| Upstream module uses `lib.uniqueStrings` and `lib.types.pathWith` | Low | Both verified present in the pinned nixpkgs 26.05 |
| Secret filenames visible in a public repo | Low | Accepted; names already appear in the NixOS config regardless |

## Repo hygiene

- **Never-commit guard.** Add `.gitignore` patterns for the private-key filenames
  (`identity.txt`, `keys.txt`) so a stray copy inside the repo cannot be staged. The
  keys' real homes are outside the repo, but the cost of the guard is one line.
- **Pre-commit hooks.** `nix develop` installs alejandra, convco, and a trufflehog secret
  scan (`flake/modules/per-system.nix`). New `.nix` files must be alejandra-formatted and
  commits must be Conventional Commits. Confirm trufflehog does not flag the armored age
  ciphertext in `secrets/*.enc`; if it does, scope an exclusion for that directory rather
  than disabling the hook.

## Documentation

Rewrite the Secrets section of `CLAUDE.md`, which currently describes a non-existent
sops-nix setup. It must cover: the module and per-host file layout, the `secrets/`
directory, the `edit` → `git add` → rebuild loop, the `rekey` step when recipients
change, where keys live, and the master-key backup requirement.
