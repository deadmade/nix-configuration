# nix-secrets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt `nix-secrets` as this flake's secret manager, delivering a declarative password hash and a shared GitHub token on `deadPc` and `deadConvertible`.

**Architecture:** One auto-imported core module (`modules/nixos/core/nixSecrets.nix`) carries the flake input, storage location, identity paths, recipient aliases, and all *shared* secret declarations — but never sets `enable`. Each host opts in via `hosts/<name>/secrets.nix`, which also holds the host-local password wiring. Encrypted files live in `secrets/` in this repo; private keys live only on local disk and are never committed.

**Tech Stack:** NixOS 26.05, flake-parts, `nix-secrets` (age/rage, Rust CLI), Home Manager 26.05, alejandra, convco.

**Spec:** `docs/superpowers/specs/2026-08-18-nix-secrets-design.md`

## Global Constraints

- **Conventional Commits are enforced** by the `convco` pre-commit hook. Every commit message must match `type(scope): subject`.
- **`alejandra` formats all `.nix` files** via pre-commit. Run `nix fmt` before committing.
- **`git add` before any `nix eval`/`nix build`.** Untracked files are invisible to flake evaluation, so a new module or `.enc` file that is not staged does not exist as far as Nix is concerned.
- **Never commit a private key.** Private keys live at `/var/lib/nix-secrets/identity.txt` (root, `0400`) and `~/.config/nix-secrets/keys.txt` (user, `0400`). Only `age1…` public keys go in `.nix` files.
- **`deadPc` runs nix-mineral.** Prefer `sudo nixos-rebuild boot --flake .#deadPc` + reboot over `switch` for risky changes, so the prior generation stays bootable. Exception: Task 6, where an open root shell is the real safety net because `/etc/shadow` is imperative state that survives a generation rollback.
- **A declared secret with no `.enc` file makes the switch fail**, not warn. Always create the secret before the first switch that declares it.
- **Every enabled host must already be a recipient of every shared secret**, or its activation fails on the secret it cannot decrypt.
- **`sudo nixos-rebuild dry-activate --flake .#<host>` is the pre-flight gate.** It decrypts every secret and template — proving keys, ciphertext, and recipient lists — but skips linking them into final paths and does not touch users or `/etc/shadow`.
- The repo's `nh` aliases are `nos` (`nh os switch .`) and `nhs` (`nh home switch .`).

---

### Task 1: Flake input, shared module skeleton, storage directory

Adds `nix-secrets` to the flake and puts the shared module on every host, with nothing enabled anywhere. Deliverable: the flake evaluates and `security.nix-secrets.enable` exists and is `false` on all five hosts.

**Files:**
- Modify: `flake.nix` (inputs block, after the `nixsecauditor` entry at ~line 158)
- Create: `modules/nixos/core/nixSecrets.nix`
- Create: `secrets/.gitkeep`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `inputs.nix-secrets`; the option tree `security.nix-secrets.*` on every host; a buildable CLI at `.#nixosConfigurations.<host>.config.security.nix-secrets.package`.

- [ ] **Step 1: Confirm the option does not exist yet**

```bash
cd /home/deadmade/nix-configuration
nix eval .#nixosConfigurations.deadPc.config.security.nix-secrets.enable
```

Expected: FAIL — `error: attribute 'nix-secrets' missing`. This is the baseline that proves Step 5 actually did something.

- [ ] **Step 2: Add the flake input**

In `flake.nix`, immediately after the `nixsecauditor` input block, add:

```nix
    nix-secrets = {
      type = "github";
      owner = "unnamed-systems";
      repo = "nix-secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 3: Create the storage directory**

Git cannot track an empty directory, and `storage` must point at a real path.

```bash
mkdir -p secrets
touch secrets/.gitkeep
```

- [ ] **Step 4: Create the shared module**

Create `modules/nixos/core/nixSecrets.nix`. Note there is deliberately **no `enable`** here — that is each host's opt-in — and no `recipientAliases` yet, because no keys exist until Task 2.

```nix
{
  inputs,
  vars,
  ...
}: {
  imports = [inputs.nix-secrets.nixosModules.default];

  # Shared nix-secrets infrastructure for every host. Deliberately does NOT set
  # `enable`: a host opts in from its own hosts/<name>/secrets.nix once its age
  # key exists. Hosts that never opt in are entirely unaffected by this module.
  security.nix-secrets = {
    # Encrypted files, copied into the store as part of the closure. Age
    # ciphertext is safe in this public repo; the private keys never enter git.
    storage = ../../../secrets;

    # Only supplies the CLI's default --storage. Harmless on headless hosts
    # where the repo lives elsewhere and the CLI is never run.
    storagePath = "/home/${vars.username}/nix-configuration/secrets";

    # get_identities() filters on path.is_file(), so listing the master key on
    # every host is safe -- hosts without it silently skip it.
    identityPaths = [
      "/var/lib/nix-secrets/identity.txt" # this host's key, root:root 0400
      "/home/${vars.username}/.config/nix-secrets/keys.txt" # master key, deadPc only
    ];
  };
}
```

- [ ] **Step 5: Add the never-commit guard to `.gitignore`**

Append to `.gitignore`:

```
# nix-secrets private keys. Their real homes are outside the repo
# (/var/lib/nix-secrets/, ~/.config/nix-secrets/); this is a guard against a
# stray copy ever being staged.
identity.txt
keys.txt
```

- [ ] **Step 6: Stage everything and format**

```bash
nix fmt
git add flake.nix flake.lock .gitignore secrets/.gitkeep modules/nixos/core/nixSecrets.nix
```

- [ ] **Step 7: Verify the option now exists**

```bash
nix eval .#nixosConfigurations.deadPc.config.security.nix-secrets.enable
nix eval .#nixosConfigurations.deadPi.config.security.nix-secrets.enable
```

Expected: `false` for both. `deadPi` proves the module is inert on hosts that never opt in.

- [ ] **Step 8: Verify the CLI builds**

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package
```

Expected: a store path ending in `-nix-secrets-<version>`. This is a from-source Rust build (`nix-secrets` is not in nixpkgs), so expect a few minutes on first run.

- [ ] **Step 9: Verify the whole flake still evaluates**

```bash
nix flake check
```

Expected: PASS. Informational warnings about the custom `nixosProfiles`/`homeManagerModules` outputs are pre-existing and expected.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(secrets): add nix-secrets input and shared module"
```

---

### Task 2: Generate keys and register recipient aliases

Creates the master key and `deadPc`'s host key, then records their public halves. Deliverable: `recipientAliases` and `defaultRecipients` are populated and every secret created from here on is readable by the master key.

**Files:**
- Modify: `modules/nixos/core/nixSecrets.nix`

**Interfaces:**
- Consumes: `security.nix-secrets.package` from Task 1.
- Produces: aliases `master` and `deadPc`; `defaultRecipients = ["master"]`, so later tasks may omit `master` from per-secret recipient lists.

- [ ] **Step 1: Put the CLI on PATH for this shell**

```bash
cd /home/deadmade/nix-configuration
export PATH="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package)/bin:$PATH"
nix-secrets --help
```

Expected: the CLI's help text, listing `activate`, `edit`, `keygen`, `rekey`, `regenerate`.

- [ ] **Step 2: Generate the master key**

`nix-secrets keygen` writes mode `0600` and records the public key as a `# public key:` comment inside the file.

```bash
mkdir -p ~/.config/nix-secrets
chmod 700 ~/.config/nix-secrets
nix-secrets keygen -o ~/.config/nix-secrets/keys.txt
chmod 400 ~/.config/nix-secrets/keys.txt
grep '# public key:' ~/.config/nix-secrets/keys.txt
```

Record the printed `age1…` value as **MASTER_PUBKEY**.

- [ ] **Step 3: Back up the master key — do not skip this**

If every copy of `~/.config/nix-secrets/keys.txt` is lost, every secret encrypted to it is permanently unrecoverable. There is no reset.

```bash
cat ~/.config/nix-secrets/keys.txt
```

Copy the full contents into your password manager, and make one offline copy. Do this **now**, before any secret exists — the cost of losing the key grows with every secret added.

- [ ] **Step 4: Generate deadPc's host key**

Generated as your user in a `0700` temp dir, then installed root-owned, so the private key is never world-readable at any point.

```bash
TMPD=$(mktemp -d)
nix-secrets keygen -o "$TMPD/identity.txt"
grep '# public key:' "$TMPD/identity.txt"
sudo install -D -m 0400 -o root -g root "$TMPD/identity.txt" /var/lib/nix-secrets/identity.txt
shred -u "$TMPD/identity.txt"
rmdir "$TMPD"
sudo ls -l /var/lib/nix-secrets/identity.txt
```

Record the printed `age1…` value as **DEADPC_PUBKEY**. Expected from `ls`: `-r-------- 1 root root`.

- [ ] **Step 5: Register the aliases**

In `modules/nixos/core/nixSecrets.nix`, inside `security.nix-secrets`, add — substituting the two values recorded above:

```nix
    # Public keys only. Aliases are added as each host's key is generated.
    recipientAliases = {
      master = "MASTER_PUBKEY"; # personal key, ~/.config/nix-secrets/keys.txt on deadPc
      deadPc = "DEADPC_PUBKEY"; # /var/lib/nix-secrets/identity.txt on deadPc
    };

    # Every secret is additionally encrypted to the master key, so secrets can
    # always be read and rekeyed from deadPc. Without this, adding a new host
    # later would be impossible.
    defaultRecipients = ["master"];
```

- [ ] **Step 6: Verify the aliases resolve**

```bash
nix fmt
git add modules/nixos/core/nixSecrets.nix
nix eval .#nixosConfigurations.deadPc.config.security.nix-secrets.defaultRecipients
```

Expected: a single-element list containing your MASTER_PUBKEY — the alias resolved to the raw recipient. If it instead prints `[ "master" ]`, the alias name did not match and the value would be rejected as an invalid age recipient later.

- [ ] **Step 7: Confirm no private key is staged**

```bash
git diff --cached | grep -i 'AGE-SECRET-KEY' && echo "ABORT: private key staged" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(secrets): register master and deadPc age recipients"
```

---

### Task 3: Declare and create the GitHub token, enable deadPc

The pilot secret. Chosen over the password because a broken token costs a `gh auth login`, whereas a broken password can lock the account. Deliverable: `/run/nix-secrets/github/token` exists on deadPc with the right owner and mode.

**Files:**
- Modify: `modules/nixos/core/nixSecrets.nix` (shared secret declaration)
- Create: `hosts/deadPc/secrets.nix`
- Modify: `hosts/deadPc/config.nix` (imports list, ~line 18)
- Create: `secrets/github/token.enc` (via the CLI, not by hand)

**Interfaces:**
- Consumes: aliases and `defaultRecipients` from Task 2.
- Produces: the secret `"github/token"`, readable at `config.security.nix-secrets.secrets."github/token".path` = `/run/nix-secrets/github/token`, owned by `deadmade`, mode `0400`. Task 4 consumes this path.

- [ ] **Step 1: Declare the shared secret**

A secret name maps to exactly one file in storage, encrypted to exactly one recipient list — so shared secrets are declared once, here, with every host that will ever be enabled. Per-host declarations would let the lists diverge, and `rekey` (which evaluates a single host's manifest) would then lock other hosts out.

In `modules/nixos/core/nixSecrets.nix`, inside `security.nix-secrets`, add:

```nix
    # Shared secrets are declared once here, not per host: one secret name maps
    # to one file in storage encrypted to one recipient list. `recipients` must
    # list every host that will ever set `enable`, because an enabled host that
    # is not a recipient fails activation on the secret it cannot decrypt.
    # `master` is added automatically via defaultRecipients.
    secrets = {
      "github/token" = {
        recipients = ["deadPc"];
        owner = vars.username;
        mode = "0400";
      };
    };
```

- [ ] **Step 2: Create the host opt-in file**

Create `hosts/deadPc/secrets.nix`:

```nix
{...}: {
  # Opt deadPc into nix-secrets. Shared secret declarations and all the
  # infrastructure live in modules/nixos/core/nixSecrets.nix; this file holds
  # only deadPc's opt-in and any host-local wiring.
  security.nix-secrets.enable = true;
}
```

- [ ] **Step 3: Import it from the host config**

In `hosts/deadPc/config.nix`, add `./secrets.nix` to the `imports` list, after `./mainboard.nix`:

```nix
    ./hardware-configuration.nix
    ./mainboard.nix
    ./secrets.nix
```

- [ ] **Step 4: Stage, and verify the secret's path resolves**

```bash
nix fmt
git add modules/nixos/core/nixSecrets.nix hosts/deadPc/secrets.nix hosts/deadPc/config.nix
nix eval --raw .#nixosConfigurations.deadPc.config.security.nix-secrets.secrets.\"github/token\".path
```

Expected: `/run/nix-secrets/github/token`.

- [ ] **Step 5: Confirm the switch would fail right now**

The secret is declared but its `.enc` does not exist. Activation errors rather than warning on a missing file, so this must fail — confirming why the secret has to be created before the first switch.

```bash
sudo nixos-rebuild dry-activate --flake .#deadPc
```

Expected: FAIL, with an error mentioning `secrets/github/token.enc`. If this unexpectedly succeeds, stop and investigate before continuing.

- [ ] **Step 6: Create a GitHub token to store**

At <https://github.com/settings/tokens>, create a fine-grained or classic PAT with `repo` scope (add `read:packages` if you pull from GHCR). Copy it; GitHub will not show it again.

- [ ] **Step 7: Encrypt it into storage**

`storagePath` is set, so no `--storage` flag is needed. `$EDITOR` must be set — the CLI opens the plaintext in it.

```bash
export PATH="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package)/bin:$PATH"
export EDITOR=nvim
nix-secrets edit github/token
```

Paste **only** the token, with no trailing newline or surrounding whitespace, then save and quit.

- [ ] **Step 8: Verify the file is real ciphertext, then stage it**

```bash
head -1 secrets/github/token.enc
git add secrets/github/token.enc
```

Expected from `head`: `-----BEGIN AGE ENCRYPTED FILE-----`. If you see your token in plaintext, stop — do not commit.

- [ ] **Step 9: Verify decryption round-trips**

```bash
nix-secrets edit github/token
```

Expected: your editor opens showing the token you entered. Quit without changes. This proves the master key decrypts what it encrypted.

- [ ] **Step 10: Pre-flight the activation**

```bash
sudo nixos-rebuild dry-activate --flake .#deadPc
```

Expected: PASS. Dry mode decrypts every secret — proving key, ciphertext, and recipient list are all correct — but skips linking into `/run/nix-secrets`.

- [ ] **Step 11: Apply**

deadPc runs nix-mineral, so use `boot` + reboot to keep the prior generation bootable.

```bash
sudo nixos-rebuild boot --flake .#deadPc
sudo reboot
```

- [ ] **Step 12: Verify the decrypted secret after reboot**

```bash
ls -l /run/nix-secrets/github/token
cat /run/nix-secrets/github/token
findmnt /run/nix-secrets
```

Expected: `-r-------- 1 deadmade`; the file contains your token; `findmnt` shows a `ramfs` or `tmpfs` mount, confirming it is RAM-only and gone on reboot.

- [ ] **Step 13: Commit**

```bash
git commit -m "feat(secrets): store github token and enable nix-secrets on deadPc"
```

---

### Task 4: Wire the token into gh, git, and the Nix daemon

Makes the token actually do something. Deliverable: `gh auth status` works without an interactive login, and the Nix daemon uses the token for GitHub API calls.

**Files:**
- Create: `modules/home-manager/coding/githubAuth.nix`
- Modify: `modules/nixos/core/nixSecrets.nix` (template + `nix.extraOptions`)

**Interfaces:**
- Consumes: `/run/nix-secrets/github/token` from Task 3.
- Produces: `GH_TOKEN` in interactive zsh; the template `nixAccessTokens` at `/run/nix-secrets/templates/nixAccessTokens`.

Placement note: `modules/home-manager/coding/` is auto-imported by the `desktopDev` HM profile via `builtins.attrValues outputs.homeManagerModules.coding`, which reaches deadPc and deadConvertible. The `wsl` HM profile imports only `coding.direnv` explicitly, so deadWsl is untouched.

- [ ] **Step 1: Confirm git already routes through gh**

```bash
nix eval .#homeConfigurations.\"deadmade@deadPc\".config.programs.gh.gitCredentialHelper.enable
```

Expected: `true`. `programs.gh.enable` is already set in `modules/home-manager/core/git.nix`, and the helper defaults on, so Home Manager already sends `github.com` credentials to `gh auth git-credential`. That means no custom git credential helper is needed — `gh` reads `GH_TOKEN` from the environment and git inherits the result.

- [ ] **Step 2: Create the Home Manager module**

Create `modules/home-manager/coding/githubAuth.nix`:

```nix
{...}: let
  # NixOS-level path: nix-secrets has no Home Manager module, so this is a
  # literal string rather than a reference to config.security.nix-secrets.
  tokenPath = "/run/nix-secrets/github/token";
in {
  # gh reads GH_TOKEN from the environment, and programs.gh.gitCredentialHelper
  # (on by default) already routes git's github.com credentials through
  # `gh auth git-credential` -- so exporting this covers both tools.
  #
  # home.sessionVariables cannot be used here: it writes literal values, so
  # command substitution would not be evaluated.
  #
  # The guard keeps this a no-op on a host where the secret is absent, and on
  # deadPc before the first activation.
  programs.zsh.initContent = ''
    if [ -r ${tokenPath} ]; then
      export GH_TOKEN="$(cat ${tokenPath})"
    fi
  '';
}
```

- [ ] **Step 3: Add the Nix daemon template**

A template, not a second secret, so the token is stored exactly once. Templates default to mode `0400` owned by root — correct for the daemon.

In `modules/nixos/core/nixSecrets.nix`, add inside `security.nix-secrets`, after `secrets`:

```nix
    templates.nixAccessTokens.content = ''
      access-tokens = github.com=${config.security.nix-secrets.secrets."github/token"}
    '';
```

Then add `config` to the module's argument list so the interpolation resolves — the header becomes:

```nix
{
  config,
  inputs,
  vars,
  ...
}: {
```

- [ ] **Step 4: Point the daemon at the template**

Still in `modules/nixos/core/nixSecrets.nix`, add at the top level of the returned attrset, after the `security.nix-secrets` block:

```nix
  # `!include` (unlike `include`) ignores a missing file, so this is safe on
  # hosts where nix-secrets is disabled and the template never materialises.
  nix.extraOptions = "!include ${config.security.nix-secrets.templates.nixAccessTokens.path}";
```

- [ ] **Step 5: Stage and verify both wirings evaluate**

```bash
nix fmt
git add modules/nixos/core/nixSecrets.nix modules/home-manager/coding/githubAuth.nix
nix eval --raw .#nixosConfigurations.deadPc.config.security.nix-secrets.templates.nixAccessTokens.path
nix eval --raw .#nixosConfigurations.deadPc.config.nix.extraOptions
```

Expected: `/run/nix-secrets/templates/nixAccessTokens`, and an `extraOptions` string containing `!include /run/nix-secrets/templates/nixAccessTokens`.

- [ ] **Step 6: Confirm the template does not leak the token into the store**

```bash
nix eval --raw .#nixosConfigurations.deadPc.config.security.nix-secrets.templates.nixAccessTokens.content
```

Expected: the `access-tokens = github.com=` line followed by a `{{NIX_SECRETS-<hash>}}` placeholder — **not** your actual token. The real value is substituted at activation time. If you see the token here, stop: it would be world-readable in `/nix/store`.

- [ ] **Step 7: Pre-flight and apply**

```bash
sudo nixos-rebuild dry-activate --flake .#deadPc
sudo nixos-rebuild boot --flake .#deadPc
sudo reboot
```

- [ ] **Step 8: Apply the Home Manager side**

```bash
nhs
```

- [ ] **Step 9: Verify all three consumers**

```bash
exec zsh
echo "${GH_TOKEN:0:4}…"
gh auth status
git ls-remote https://github.com/deadmade/nix-configuration >/dev/null && echo "git ok"
sudo cat /run/nix-secrets/templates/nixAccessTokens
nix flake metadata github:nixos/nixpkgs >/dev/null && echo "nix ok"
```

Expected: a token prefix; `gh auth status` reporting a token from `GH_TOKEN`; `git ok`; the template showing the real `access-tokens = github.com=<token>` line; `nix ok`.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(secrets): wire github token into gh, git and the nix daemon"
```

---

### Task 5: Declare the password secrets, inert

Lands both password secrets and the `hashedPasswordFile` wiring while `mutableUsers` is still `true`, where the options cannot touch `/etc/shadow`. Deliverable: verified-decryptable password hashes at `/run/nix-secrets-for-users/`, with zero risk taken.

Why this is split from Task 6: verified in `nixpkgs` `nixos/modules/config/update-users-groups.pl:299-300`, a user already present in `/etc/shadow` only receives the declarative hash when `mutableUsers = false`. `deadmade` exists and `mutableUsers` defaults to `true`, so everything in this task is inert — which is exactly what makes it a safe place to prove the hashes decrypt.

**Files:**
- Modify: `modules/nixos/core/nixSecrets.nix` (two secret declarations)
- Modify: `hosts/deadPc/secrets.nix` (`hashedPasswordFile` wiring)

**Interfaces:**
- Consumes: aliases and `defaultRecipients` from Task 2.
- Produces: secrets `password` and `root-password`, both `neededForUsers = true`, resolving to `/run/nix-secrets-for-users/password` and `/run/nix-secrets-for-users/root-password`. Task 6 flips the switch that makes them take effect.

- [ ] **Step 1: Declare both secrets**

`neededForUsers` secrets are decrypted before user creation and therefore cannot set `owner` or `group`. One shared password across hosts is intentional — one login, not one per machine.

In `modules/nixos/core/nixSecrets.nix`, extend the `secrets` attrset:

```nix
      # neededForUsers secrets are decrypted to /run/nix-secrets-for-users
      # before NixOS creates users, which is what makes hashedPasswordFile
      # work. They cannot set owner or group for that reason.
      password = {
        recipients = ["deadPc"];
        neededForUsers = true;
      };

      # Fallback account. users.mutableUsers = false locks every account whose
      # hash is undefined, root included, so root needs its own hash to
      # guarantee a second way in.
      root-password = {
        recipients = ["deadPc"];
        neededForUsers = true;
      };
```

- [ ] **Step 2: Generate the two hashes**

```bash
nix shell nixpkgs#mkpasswd
echo "your-deadmade-password" | mkpasswd -s
echo "your-root-password" | mkpasswd -s
```

Each prints a `$y$…` yescrypt hash. Keep both to hand for Step 4, and store the plaintext passwords in your password manager now.

- [ ] **Step 3: Verify the secrets' paths, and that the switch would fail**

```bash
nix fmt
git add modules/nixos/core/nixSecrets.nix
nix eval --raw .#nixosConfigurations.deadPc.config.security.nix-secrets.secrets.password.path
sudo nixos-rebuild dry-activate --flake .#deadPc
```

Expected: `/run/nix-secrets-for-users/password`, then a FAILING dry-activate naming the missing `secrets/password.enc` — the same missing-file behaviour as Task 3 Step 5.

- [ ] **Step 4: Encrypt both hashes**

```bash
export PATH="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package)/bin:$PATH"
export EDITOR=nvim
nix-secrets edit password
nix-secrets edit root-password
```

In each editor session paste **only** the corresponding `$y$…` hash — not the plaintext password, and no trailing whitespace.

- [ ] **Step 5: Verify the ciphertext, then stage**

```bash
head -1 secrets/password.enc
head -1 secrets/root-password.enc
git add secrets/password.enc secrets/root-password.enc
```

Expected: `-----BEGIN AGE ENCRYPTED FILE-----` from both.

- [ ] **Step 6: Add the wiring, still inert**

In `hosts/deadPc/secrets.nix`, replace the file contents with:

```nix
{
  config,
  vars,
  ...
}: {
  # Opt deadPc into nix-secrets. Shared secret declarations and all the
  # infrastructure live in modules/nixos/core/nixSecrets.nix; this file holds
  # only deadPc's opt-in and any host-local wiring.
  security.nix-secrets.enable = true;

  # These are INERT until users.mutableUsers = false, because
  # update-users-groups.pl only applies a declarative hash to an existing
  # /etc/shadow entry when mutableUsers is off. The flip is a separate commit,
  # deliberately: see docs/superpowers/plans/2026-08-18-nix-secrets.md Task 6.
  #
  # This wiring must stay per-host. modules/nixos/core/user.nix is imported by
  # every host, so putting it there would lock the accounts on deadServer,
  # deadPi and deadWsl, none of which have a password secret.
  users.users.${vars.username}.hashedPasswordFile =
    config.security.nix-secrets.secrets.password.path;
  users.users.root.hashedPasswordFile =
    config.security.nix-secrets.secrets.root-password.path;
}
```

- [ ] **Step 7: Confirm `mutableUsers` is still on**

```bash
nix fmt
git add hosts/deadPc/secrets.nix
nix eval .#nixosConfigurations.deadPc.config.users.mutableUsers
```

Expected: `true`. If this is `false`, stop — Task 6's safety sequence has been skipped.

- [ ] **Step 8: Pre-flight and apply**

```bash
sudo nixos-rebuild dry-activate --flake .#deadPc
sudo nixos-rebuild boot --flake .#deadPc
sudo reboot
```

- [ ] **Step 9: Verify the hashes decrypted, and that nothing changed**

```bash
sudo ls -l /run/nix-secrets-for-users/
sudo cat /run/nix-secrets-for-users/password
sudo cat /run/nix-secrets-for-users/root-password
sudo getent shadow deadmade | cut -d: -f2 | head -c 8
```

Expected: both files present and each holding the matching `$y$…` hash. The `getent` output is your **old** imperative hash prefix, not the new one — proving the wiring is genuinely inert and this switch was risk-free. Note the old prefix; Task 6 checks that it changes.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(secrets): add password hashes for deadPc, not yet active"
```

---

### Task 6: Activate declarative passwords on deadPc

The one genuinely risky step. Deliverable: `deadmade` and `root` authenticate from the nix-secrets hashes.

**Read this before starting.** With `mutableUsers = false`, `update-users-groups.pl:299` writes `!` — a locked account — for any user whose hash is undefined. `/etc/shadow` is imperative state, so a bad outcome **survives a generation rollback**: booting the previous generation leaves `mutableUsers = true`, under which lines 299-300 do not fire and the `!` is preserved. Recovery would need `init=/bin/sh` or live media. The open root shell in Step 2, not the bootable prior generation, is the actual safety net. Task 5's verification is the precondition — do not start here if Step 9 of Task 5 did not show both hashes.

A second consequence: `passwd` stops persisting changes. From here on, changing your password means editing the secret and rebuilding.

**Files:**
- Modify: `hosts/deadPc/secrets.nix`

**Interfaces:**
- Consumes: the verified secrets from Task 5.
- Produces: `users.mutableUsers = false` on deadPc.

- [ ] **Step 1: Re-confirm the hashes are still decryptable**

```bash
sudo cat /run/nix-secrets-for-users/password
sudo cat /run/nix-secrets-for-users/root-password
```

Expected: both `$y$…` hashes. If either is missing or empty, **stop** and fix Task 5 first.

- [ ] **Step 2: Open the safety net**

On a second TTY (Ctrl-Alt-F3), log in and run:

```bash
sudo -i
```

Leave this root shell open for the remainder of the task. If login breaks, `passwd deadmade` here repairs it without a reboot. Do not close it until Step 6 passes.

- [ ] **Step 3: Flip mutableUsers**

In `hosts/deadPc/secrets.nix`, add after `security.nix-secrets.enable = true;`:

```nix
  # Required for the hashedPasswordFile options below to take effect at all:
  # update-users-groups.pl only applies a declarative hash to an existing
  # /etc/shadow entry when mutableUsers is false. Consequence: `passwd` no
  # longer persists -- change the password by editing the secret and rebuilding.
  users.mutableUsers = false;
```

Then update the comment above the wiring, replacing "These are INERT until users.mutableUsers = false, because" through "deliberately: see docs/superpowers/plans/2026-08-18-nix-secrets.md Task 6." with:

```nix
  # Declarative passwords, active because mutableUsers is false above. Both
  # accounts get a hash: with mutableUsers off, any account whose hash is
  # undefined is locked to `!`.
  #
  # This wiring must stay per-host. modules/nixos/core/user.nix is imported by
  # every host, so putting it there would lock the accounts on deadServer,
  # deadPi and deadWsl, none of which have a password secret.
```

- [ ] **Step 4: Stage and pre-flight**

```bash
nix fmt
git add hosts/deadPc/secrets.nix
nix eval .#nixosConfigurations.deadPc.config.users.mutableUsers
sudo nixos-rebuild dry-activate --flake .#deadPc
```

Expected: `false`, then a PASSING dry-activate. Dry mode does not run user updates, so `/etc/shadow` is still untouched at this point.

- [ ] **Step 5: Apply with `switch`, not `boot`**

`switch` is the right choice here precisely because it fails fast while the root shell is open. `boot` + reboot would defer the outcome to a login prompt you might not be able to get past.

```bash
sudo nixos-rebuild switch --flake .#deadPc
```

- [ ] **Step 6: Verify before closing the root shell**

```bash
sudo getent shadow deadmade | cut -d: -f2
sudo getent shadow root | cut -d: -f2
```

Expected: each field is the matching `$y$…` hash — **not** `!`, and not the old prefix noted in Task 5 Step 9. If either shows `!`, run `passwd deadmade` in the open root shell immediately, then investigate before rebooting.

Then, on a third TTY, log in as `deadmade` with the password whose hash you stored. Only once that login succeeds, close the root shell.

- [ ] **Step 7: Verify it survives a reboot**

```bash
sudo reboot
```

Log in normally after reboot. This confirms the `neededForUsers` activation script runs early enough on a cold boot, not just on a live `switch`.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(secrets): activate declarative passwords on deadPc"
```

---

### Task 7: Roll out to deadConvertible

Deliverable: deadConvertible decrypts the same GitHub token and password as deadPc, using its own key.

The order below is mandatory: an enabled host that is not yet a recipient fails activation on the first secret it cannot decrypt. Recipient first, enable last.

**Files:**
- Modify: `modules/nixos/core/nixSecrets.nix` (alias + three recipient lists)
- Create: `hosts/deadConvertible/secrets.nix`
- Modify: `hosts/deadConvertible/config.nix` (imports list)
- Modify: `secrets/github/token.enc`, `secrets/password.enc`, `secrets/root-password.enc` (via `rekey`)

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: alias `deadConvertible`; all three shared secrets encrypted to it.

- [ ] **Step 1: Generate deadConvertible's host key**

Run this **on deadConvertible**:

```bash
cd /home/deadmade/nix-configuration
export PATH="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadConvertible.config.security.nix-secrets.package)/bin:$PATH"
TMPD=$(mktemp -d)
nix-secrets keygen -o "$TMPD/identity.txt"
grep '# public key:' "$TMPD/identity.txt"
sudo install -D -m 0400 -o root -g root "$TMPD/identity.txt" /var/lib/nix-secrets/identity.txt
shred -u "$TMPD/identity.txt"
rmdir "$TMPD"
```

Record the `age1…` value as **DEADCONV_PUBKEY**. The private key stays on this machine and is never copied anywhere.

- [ ] **Step 2: Register the alias**

Back **on deadPc**, in `modules/nixos/core/nixSecrets.nix`, add to `recipientAliases`:

```nix
      deadConvertible = "DEADCONV_PUBKEY"; # /var/lib/nix-secrets/identity.txt on deadConvertible
```

- [ ] **Step 3: Add it to all three recipient lists**

In the same file, change each of the three `recipients` lines to:

```nix
        recipients = ["deadPc" "deadConvertible"];
```

That is `"github/token"`, `password`, and `root-password`. Missing one means deadConvertible fails activation on that secret in Step 8.

- [ ] **Step 4: Stage and verify the recipient lists**

```bash
nix fmt
git add modules/nixos/core/nixSecrets.nix
nix eval .#nixosConfigurations.deadPc.config.security.nix-secrets.secrets.password.recipients
```

Expected: three raw `age1…` values — MASTER_PUBKEY, DEADPC_PUBKEY, and DEADCONV_PUBKEY, in any order. `recipients` merges the per-secret list with `defaultRecipients` and its `apply` resolves aliases and dedupes (`nixos/options/secrets.nix:31-33,187`), so seeing an unresolved `"deadConvertible"` string here means the alias name does not match Step 2.

- [ ] **Step 5: Rekey the existing files**

The `.enc` files are still encrypted only to master and deadPc. `rekey` re-encrypts them to the updated recipient lists, using the master key to read them first.

```bash
export PATH="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.deadPc.config.security.nix-secrets.package)/bin:$PATH"
nix-secrets rekey github/token password root-password
git diff --stat secrets/
```

Expected: all three `.enc` files show as modified. If a file is unchanged, its recipient list did not actually change — recheck Step 3.

- [ ] **Step 6: Confirm deadPc still decrypts, then commit**

Rekeying rewrites the files deadPc depends on, so verify it before moving on.

```bash
git add secrets/
sudo nixos-rebuild dry-activate --flake .#deadPc
git commit -m "feat(secrets): add deadConvertible as a recipient"
git push
```

Expected: a PASSING dry-activate on deadPc.

- [ ] **Step 7: Create the host opt-in file**

Create `hosts/deadConvertible/secrets.nix` — identical in shape to deadPc's, since the secrets themselves are shared:

```nix
{
  config,
  vars,
  ...
}: {
  # Opt deadConvertible into nix-secrets. Shared secret declarations and all the
  # infrastructure live in modules/nixos/core/nixSecrets.nix.
  security.nix-secrets.enable = true;

  # Required for the hashedPasswordFile options below to take effect at all:
  # update-users-groups.pl only applies a declarative hash to an existing
  # /etc/shadow entry when mutableUsers is false. Consequence: `passwd` no
  # longer persists -- change the password by editing the secret and rebuilding.
  users.mutableUsers = false;

  # Both accounts get a hash: with mutableUsers off, any account whose hash is
  # undefined is locked to `!`. Kept per-host, not in core/user.nix, which every
  # host imports.
  users.users.${vars.username}.hashedPasswordFile =
    config.security.nix-secrets.secrets.password.path;
  users.users.root.hashedPasswordFile =
    config.security.nix-secrets.secrets.root-password.path;
}
```

- [ ] **Step 8: Import it, then verify on deadConvertible**

In `hosts/deadConvertible/config.nix`, add `./secrets.nix` to the `imports` list after `./hardware-configuration.nix`. Then, **on deadConvertible**, pull the commit from Step 6 and run:

```bash
nix fmt
git add hosts/deadConvertible/secrets.nix hosts/deadConvertible/config.nix
sudo nixos-rebuild dry-activate --flake .#deadConvertible
```

Expected: PASS. This proves deadConvertible's own key decrypts all three rekeyed secrets — the whole point of the task.

- [ ] **Step 9: Apply with the same safety net as Task 6**

deadConvertible is getting `mutableUsers = false` for the first time, so the Task 6 lockout risk applies in full.

Open a root shell on a second TTY (`sudo -i`) and leave it open. Then:

```bash
sudo nixos-rebuild switch --flake .#deadConvertible
sudo getent shadow deadmade | cut -d: -f2
cat /run/nix-secrets/github/token
```

Expected: the `$y$…` hash rather than `!`, and the same token value as on deadPc. Log in as `deadmade` on a third TTY before closing the root shell.

- [ ] **Step 10: Apply Home Manager and commit**

```bash
nhs
exec zsh
gh auth status
git commit -m "feat(secrets): enable nix-secrets on deadConvertible"
```

---

### Task 8: Rewrite the CLAUDE.md Secrets section

`CLAUDE.md` currently documents a `sops-nix` setup that has never existed in this repo — no `.sops.yaml`, no `secrets/` before Task 1, no `hosts/deadPc/sops.nix`, and no `sops-nix` input. Left as-is it would send every future contributor, human or agent, down a wrong path.

**Files:**
- Modify: `CLAUDE.md` (the `### Secrets` section)
- Modify: `modules/nixos/core/user.nix:8` (stale comment)

**Interfaces:**
- Consumes: the final state of Tasks 1-7.
- Produces: documentation only.

- [ ] **Step 1: Confirm what the file currently claims**

```bash
grep -n -A8 '^### Secrets' CLAUDE.md
```

Expected: the sops-nix paragraph. Confirms the section header to replace.

- [ ] **Step 2: Replace the section**

Replace the entire `### Secrets` section with:

```markdown
### Secrets

`nix-secrets` (age-based) — see `docs/superpowers/specs/2026-08-18-nix-secrets-design.md`.

- `modules/nixos/core/nixSecrets.nix` — auto-imported by every host. Holds the storage
  path, `identityPaths`, `recipientAliases` (public keys), `defaultRecipients`, and **all
  shared secret declarations**. Deliberately does not set `enable`.
- `hosts/<name>/secrets.nix` — the host's `security.nix-secrets.enable = true;` plus
  host-local wiring only (`users.mutableUsers`, `hashedPasswordFile`). Currently `deadPc`
  and `deadConvertible`.
- `secrets/<name>.enc` — age ciphertext, committed. Safe in this public repo: private
  keys never enter git.

Keys, never committed:
- `/var/lib/nix-secrets/identity.txt` — the host's own key, `root:root 0400`, generated
  on that machine with `nix-secrets keygen`.
- `~/.config/nix-secrets/keys.txt` — the master key, on `deadPc` only. In
  `defaultRecipients`, so it can read and rekey everything. **Losing every copy makes
  every secret permanently unrecoverable.**

Editing a secret:

```bash
nix-secrets edit github/token   # storagePath is set, so no --storage flag
git add secrets/github/token.enc
nos
```

Declare shared secrets **once** in `modules/nixos/core/nixSecrets.nix`, never per host: a
secret name maps to one file encrypted to one recipient list, and per-host declarations
would let the lists diverge — `rekey` evaluates a single host's manifest and would lock
the others out.

Adding a host, in this order:

1. `nix-secrets keygen` on the new host → install to `/var/lib/nix-secrets/identity.txt`.
2. Add its public key to `recipientAliases`.
3. Add its alias to the `recipients` of **every** shared secret.
4. `nix-secrets rekey` from `deadPc`, commit, push.
5. Only then set `enable = true` on that host.

Reversing 3-5 makes activation fail on the first secret the host cannot decrypt.

Gotchas:
- **`sudo nixos-rebuild dry-activate --flake .#<host>` is the pre-flight gate.** It
  decrypts everything but links nothing and does not touch `/etc/shadow`.
- A declared secret with no `.enc` file makes the switch **fail**, not warn. Create the
  secret before the first switch that declares it; the CLI is available pre-rebuild via
  `nix build --no-link --print-out-paths
  .#nixosConfigurations.<host>.config.security.nix-secrets.package`.
- On hosts with `mutableUsers = false`, `passwd` no longer persists. Change a password by
  editing the `password` secret and rebuilding.
- `/etc/shadow` is imperative state, so a bad password change **survives a generation
  rollback**. Keep a root shell open across any switch that touches it.
- `nix-secrets` has no Home Manager module. Home Manager consumes secrets as literal
  `/run/nix-secrets/...` path strings — see `modules/home-manager/coding/githubAuth.nix`.
```

- [ ] **Step 3: Fix the stale comment in `user.nix`**

In `modules/nixos/core/user.nix`, replace the line
`# Define a user account. Don't forget to set a password with 'passwd'.` with:

```nix
  # Define a user account. Password hashes are declarative on hosts that enable
  # nix-secrets (see hosts/<name>/secrets.nix); elsewhere, set one with `passwd`.
```

- [ ] **Step 4: Verify the docs match reality**

```bash
grep -rn "sops" CLAUDE.md || echo "no stale sops references"
ls modules/nixos/core/nixSecrets.nix hosts/deadPc/secrets.nix hosts/deadConvertible/secrets.nix modules/home-manager/coding/githubAuth.nix
```

Expected: `no stale sops references`, and every referenced file present. Every path named in the new section must exist.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md modules/nixos/core/user.nix
git commit -m "docs(secrets): document nix-secrets and drop stale sops-nix section"
```

---

## Deferred: Phase 4 (deadServer, deadPi)

Out of scope, and gets its own plan when there are real service credentials to store. Carried forward from the spec:

- `nix-secrets` is **not** in nixpkgs, so it builds from source with no binary cache. On deadPi that means an aarch64 Rust build — native on the Pi, or emulated on deadPc via the existing `boot.binfmt.emulatedSystems`. Check the build cost before committing, consistent with standing practice for deadPi.
- deadPi deploys via deploy-rs. Building on deadPc stays keyless; the Pi decrypts at activation with its own key.
- Both hosts must be added as recipients and rekeyed **before** being enabled.
- `deadWsl` is excluded deliberately: no secret need, and a WSL user password is meaningless.

## Watch items during execution

- **`end-of-file-fixer` pre-commit hook.** It appends a trailing newline to files it thinks lack one. Armored age files are newline-terminated, so it should be a no-op — but at Task 3 Step 8, if the hook modifies `secrets/github/token.enc`, re-run `nix-secrets edit github/token` afterwards to confirm decryption still works. If it breaks the file, exclude `secrets/` from that hook in `flake/modules/per-system.nix` rather than disabling it.
- **`trufflehog` pre-commit hook.** It should not flag age ciphertext, since its detectors are credential-pattern based. If it does flag `secrets/*.enc`, scope an exclusion for that directory rather than disabling the hook.
- **First `nix-secrets` build.** From-source Rust, uncached, a few minutes. Not a failure.
