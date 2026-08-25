# Auto-Discovered Module Registries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 11 hand-written `default.nix` registry files under `modules/` with a small in-repo helper that builds the same named registries from the directory tree.

**Architecture:** A pure-builtins function `flake/lib/registry.nix` (`dir → attrset`) maps `.nix` files to named attrs, imports directories containing a `default.nix` verbatim (the opt-out for real module dirs), and recurses into directories without one. `flake/modules/exports.nix` calls it for `nixosModules` and `homeManagerModules`. Profiles, overlays, and hosts are untouched. Spec: `docs/superpowers/specs/2026-08-01-auto-registry-design.md`.

**Tech Stack:** Nix flakes, `builtins.readDir`; no new flake inputs. Repo tooling: `alejandra` formatting, Conventional Commits enforced by convco pre-commit hook.

## Global Constraints

- The helper uses only `builtins` — no `lib`, no new flake inputs.
- Attr names are verbatim filenames minus `.nix` — no case conversion.
- Composition must be provably unchanged: `.drvPath` of every host's NixOS toplevel and every home configuration must be byte-identical before vs. after.
- Commit messages must be Conventional Commits (convco hook rejects otherwise).
- Run `alejandra <changed .nix files>` before every commit (the pre-commit hook reformats and fails the commit otherwise).
- The working tree has unrelated uncommitted changes (podman branch work). Commit ONLY the files each task names — never `git add -A` or `git commit -a`.
- Verification files live in `V="/tmp/claude-1000/-home-deadmade-nix-configuration/7bd72be7-131c-489d-9107-8196b43118c2/scratchpad/auto-registry"`. Every task re-exports `V`. If this directory is missing at the start of Tasks 3 or 4, re-run Task 1's baseline steps first — the diffs are meaningless without a pre-change baseline.

---

### Task 1: Capture the pre-change baseline

**Files:**
- Create (scratchpad only, not committed): `$V/before-registries.json`, `$V/before-drvs.txt`

**Interfaces:**
- Consumes: current flake outputs (`.#nixosModules`, `.#homeManagerModules`, `.#nixosConfigurations`, `.#homeConfigurations`).
- Produces: `$V/before-registries.json` (two-level attr-name dump of both module registries) and `$V/before-drvs.txt` (lines `<name>: <drvPath>` for every NixOS host and home configuration). Tasks 3 and 4 diff against these exact files.

- [ ] **Step 1: Dump registry attr names**

```bash
cd /home/deadmade/nix-configuration
export V="/tmp/claude-1000/-home-deadmade-nix-configuration/7bd72be7-131c-489d-9107-8196b43118c2/scratchpad/auto-registry"
mkdir -p "$V"
nix eval --impure --json \
  --expr 'import /home/deadmade/nix-configuration/modules/nixos' \
  --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' > "$V/before-nixos.json"
nix eval --json --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' '.#homeManagerModules' > "$V/before-home.json"
jq -s '{nixos: .[0], home: .[1]}' "$V/before-nixos.json" "$V/before-home.json" > "$V/before-registries.json"
```

The nixos dump MUST bypass the flake output: flake-parts types `flake.nixosModules` and wraps each entry in a `{_class, _file, imports}` module shim, so `nix eval '.#nixosModules'` shows only wrapper attrs and would make the before/after diff blind. `homeManagerModules` is untyped and passes through unwrapped, so the flake output is fine there.

- [ ] **Step 2: Verify the dump is sane**

Run: `jq . "$V/before-registries.json"`
Expected: `.nixos` has keys `core desktop gaming virtualization`, each listing real module names (e.g. `.nixos.core` = `defaults grub2-bootloader localization network nixsecauditor optimize packages security themes user`, sorted) — NOT `_class`/`_file`/`imports`; `.home` has keys `core browser hyprland coding terminal gaming socialMedia flatpak`; `.home.hyprland`, `.home.gaming`, `.home.flatpak` are `"leaf"`.

- [ ] **Step 3: Capture drvPaths for every host and home config**

```bash
cd /home/deadmade/nix-configuration
for h in $(nix eval --raw '.#nixosConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "nixos/$h: $(nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath")"
done > "$V/before-drvs.txt"
for h in $(nix eval --raw '.#homeConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "home/$h: $(nix eval --raw ".#homeConfigurations.\"$h\".activationPackage.drvPath")"
done >> "$V/before-drvs.txt"
```

This evaluates every host (including non-x86 ones); it computes derivations without building, so it works regardless of platform. Expect a few minutes.

- [ ] **Step 4: Verify the drv list is complete**

Run: `cat "$V/before-drvs.txt"`
Expected: one `nixos/<host>: /nix/store/....drv` line per host in `hosts/hosts.nix` (deadPc, deadConvertible, deadServer, deadWsl, deadPi) plus one `home/<user@host>:` line per home configuration. No empty lines, no errors interleaved.

---

### Task 2: Write and test `flake/lib/registry.nix`

**Files:**
- Create: `flake/lib/registry.nix`
- Test: `$V/test-registry.sh` (scratchpad test script, not committed)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `flake/lib/registry.nix` evaluating to a function `dir: attrset`, where `dir` is a Nix path. Rules: `<name>.nix` regular file (except `default.nix`) → attr `<name>`; directory with `default.nix` → attr imported verbatim; directory without → recursive registry, omitted when empty; dotfiles/other files ignored; file/dir name collision → `throw` containing `name collision for '<name>'`. Task 3 imports it as `import ../lib/registry.nix`.

- [ ] **Step 1: Write the failing test script**

Write `$V/test-registry.sh` (with `V` as defined in Global Constraints):

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO=/home/deadmade/nix-configuration
V="/tmp/claude-1000/-home-deadmade-nix-configuration/7bd72be7-131c-489d-9107-8196b43118c2/scratchpad/auto-registry"
F="$V/fixtures"

rm -rf "$F"
mkdir -p "$F/basic/sub" "$F/basic/moddir" "$F/basic/empty" "$F/coll/foo"
echo '{...}: {}' > "$F/basic/a.nix"
echo '{...}: {}' > "$F/basic/sub/b.nix"
echo '{...}: {}' > "$F/basic/moddir/default.nix"
echo '{...}: {}' > "$F/basic/moddir/ignored.nix"
echo 'not nix'   > "$F/basic/README.md"
echo '{...}: {}' > "$F/basic/.hidden.nix"
echo '{...}: {}' > "$F/coll/foo.nix"
echo '{...}: {}' > "$F/coll/foo/bar.nix"

# Case 1: structure — files named, default.nix dirs leaf, bare dirs recurse,
# empty dirs / non-nix / dotfiles skipped, moddir contents not scanned.
got=$(nix eval --impure --json --expr "
  let r = (import $REPO/flake/lib/registry.nix) $F/basic;
  in { top = builtins.attrNames r; sub = builtins.attrNames r.sub; moddirIsLeaf = builtins.isFunction r.moddir; }")
expected='{"moddirIsLeaf":true,"sub":["b"],"top":["a","moddir","sub"]}'
if [ "$got" != "$expected" ]; then echo "FAIL structure: $got"; exit 1; fi

# Case 2: foo.nix next to foo/ must throw at eval time.
if nix eval --impure --expr "(import $REPO/flake/lib/registry.nix) $F/coll" \
     --apply builtins.attrNames 2> "$V/coll.err"; then
  echo "FAIL: collision not detected"; exit 1
fi
grep -q "name collision for 'foo'" "$V/coll.err" || { echo "FAIL: wrong error:"; cat "$V/coll.err"; exit 1; }

echo OK
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash "$V/test-registry.sh"`
Expected: FAIL — nix eval errors with `.../flake/lib/registry.nix` does not exist (the script exits non-zero at Case 1).

- [ ] **Step 3: Write the helper**

Create `flake/lib/registry.nix`:

```nix
# Builds a module registry from a directory tree:
#   foo.nix                  -> foo = import ./foo.nix
#   bar/   (has default.nix) -> bar = import ./bar   (module or hand-written registry)
#   baz/   (no default.nix)  -> baz = nested registry (omitted when empty)
# Dotfiles, non-nix files, and empty directories are ignored.
# A file and a directory producing the same name is an eval-time error.
let
  registry = dir: let
    entries = builtins.readDir dir;

    visible =
      builtins.filter (name: builtins.substring 0 1 name != ".")
      (builtins.attrNames entries);

    isModuleFile = name:
      entries.${name}
      == "regular"
      && name != "default.nix"
      && builtins.match ".*\\.nix" name != null;

    isDir = name: entries.${name} == "directory";

    stripNix = name: builtins.substring 0 (builtins.stringLength name - 4) name;

    filePairs =
      map (name: {
        name = stripNix name;
        value = import (dir + "/${name}");
      })
      (builtins.filter isModuleFile visible);

    dirPairs = builtins.concatMap (
      name: let
        sub = dir + "/${name}";
        hasDefault = ((builtins.readDir sub)."default.nix" or null) == "regular";
        nested = registry sub;
      in
        if hasDefault
        then [
          {
            inherit name;
            value = import sub;
          }
        ]
        else if nested == {}
        then []
        else [
          {
            inherit name;
            value = nested;
          }
        ]
    ) (builtins.filter isDir visible);

    addUnique = acc: pair:
      if builtins.hasAttr pair.name acc
      then throw "registry: name collision for '${pair.name}' in ${toString dir}"
      else acc // {${pair.name} = pair.value;};
  in
    builtins.foldl' addUnique {} (filePairs ++ dirPairs);
in
  registry
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash "$V/test-registry.sh"`
Expected: `OK`

- [ ] **Step 5: Smoke-test against the real tree (registries still hand-written, so compare shape only)**

```bash
cd /home/deadmade/nix-configuration
nix eval --impure --json \
  --expr '(import ./flake/lib/registry.nix) /home/deadmade/nix-configuration/modules/nixos' \
  --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms'
```

Expected: identical to `.nixos` in `$V/before-registries.json`. Reason: every domain dir still contains its hand-written `default.nix`, so the helper's opt-out rule imports each domain verbatim — the auto-built top level wraps the same hand-written domain registries, names and all. Verify with:

```bash
diff <(jq -S .nixos "$V/before-registries.json") <(nix eval --impure --json \
  --expr '(import ./flake/lib/registry.nix) /home/deadmade/nix-configuration/modules/nixos' \
  --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' | jq -S .)
```

Expected: empty diff.

- [ ] **Step 6: Format and commit**

```bash
cd /home/deadmade/nix-configuration
alejandra flake/lib/registry.nix
git add flake/lib/registry.nix
git commit -m 'feat(flake): add directory-based module registry helper' -- flake/lib/registry.nix
```

---

### Task 3: Wire `exports.nix` through the helper (no-op checkpoint)

**Files:**
- Modify: `flake/modules/exports.nix` (whole file shown below)

**Interfaces:**
- Consumes: `flake/lib/registry.nix` from Task 2 (`import ../lib/registry.nix` = function `dir: attrset`).
- Produces: `projectOutputs.nixosModules` / `.homeManagerModules` built by the helper. Because every domain dir still contains its hand-written `default.nix`, the helper imports each verbatim — output must be byte-identical to the baseline.

- [ ] **Step 1: Rewrite `flake/modules/exports.nix`**

Replace the entire file with:

```nix
{inputs, ...}: let
  registry = import ../lib/registry.nix;
  projectOutputs = {
    overlays = import ../../overlays {inherit inputs;};
    nixosModules = registry ../../modules/nixos;
    homeManagerModules = import ../../modules/home-manager;
    nixosProfiles = import ../../profiles/nixos;
    homeManagerProfiles = import ../../profiles/home-manager;
  };
in {
  _module.args.projectOutputs = projectOutputs;
  flake = projectOutputs;
}
```

`homeManagerModules` deliberately stays on the direct import at this
checkpoint: the helper skips `dir`'s own top-level `default.nix` by rule, and
the hand-written `modules/home-manager/default.nix` is what flattens
`windowManager/hyprland` to the `hyprland` attr — routing home through the
helper here would surface `windowManager` early and break the no-op
guarantee. Task 4 switches this line to `registry ../../modules/home-manager`
together with the registry deletions and reference updates. (`modules/nixos`'s
top-level `default.nix` maps domains verbatim, so nixos is safe to route now.)

- [ ] **Step 2: Verify registries are unchanged**

```bash
cd /home/deadmade/nix-configuration
export V="/tmp/claude-1000/-home-deadmade-nix-configuration/7bd72be7-131c-489d-9107-8196b43118c2/scratchpad/auto-registry"
nix eval --impure --json \
  --expr '(import /home/deadmade/nix-configuration/flake/lib/registry.nix) /home/deadmade/nix-configuration/modules/nixos' \
  --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' > "$V/wired-nixos.json"
nix eval --json --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' '.#homeManagerModules' > "$V/wired-home.json"
diff <(jq -S . "$V/before-nixos.json") <(jq -S . "$V/wired-nixos.json")
diff <(jq -S . "$V/before-home.json")  <(jq -S . "$V/wired-home.json")
```

Expected: both diffs empty. If `windowManager` appears already, the top-level `modules/home-manager/default.nix` was deleted prematurely — restore it; deletions belong to Task 4.

- [ ] **Step 3: Verify drvPaths are unchanged**

```bash
cd /home/deadmade/nix-configuration
for h in $(nix eval --raw '.#nixosConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "nixos/$h: $(nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath")"
done > "$V/wired-drvs.txt"
for h in $(nix eval --raw '.#homeConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "home/$h: $(nix eval --raw ".#homeConfigurations.\"$h\".activationPackage.drvPath")"
done >> "$V/wired-drvs.txt"
diff "$V/before-drvs.txt" "$V/wired-drvs.txt"
```

Expected: empty diff.

- [ ] **Step 4: Format and commit**

```bash
cd /home/deadmade/nix-configuration
alejandra flake/modules/exports.nix
git add flake/modules/exports.nix
git commit -m 'refactor(flake): build module registries with auto-discovery helper' -- flake/modules/exports.nix
```

---

### Task 4: Delete hand-written registries and update the two renamed references

**Files:**
- Delete: `modules/nixos/default.nix`, `modules/home-manager/default.nix`, `modules/nixos/{core,desktop,gaming,virtualization}/default.nix`, `modules/home-manager/{core,browser,coding,terminal,socialMedia}/default.nix`
- Delete (untracked, empty): `modules/home-manager/terminal/tmux/`
- Modify: `profiles/home-manager/desktop-dev.nix:4`, `profiles/home-manager/wsl.nix:6`, `flake/modules/exports.nix:6` (homeManagerModules → helper; Task 3 left it on the direct import to preserve the no-op checkpoint)

**Interfaces:**
- Consumes: auto-discovery wiring from Task 3.
- Produces: final registry shape. Renames relative to baseline (and nothing else): hm `hyprland` (leaf) → `windowManager.hyprland`; hm `core.home` → `core.homeConfig`; hm `coding.vscode` → `coding.vscodium`; hm `terminal.nixIndex` → `terminal.nix-index`. `nixosModules` names unchanged.

- [ ] **Step 1: Delete the registry files and the stray directory**

`modules/nixos/core/default.nix` has uncommitted local modifications (the `nixsecauditor` registration line, whose module file `nixsecauditor.nix` is already staged separately). That registration becomes automatic under auto-discovery, so discarding the edit via `-f` is correct here:

```bash
cd /home/deadmade/nix-configuration
git rm -f modules/nixos/core/default.nix
git rm modules/nixos/default.nix modules/home-manager/default.nix \
  modules/nixos/desktop/default.nix modules/nixos/gaming/default.nix \
  modules/nixos/virtualization/default.nix \
  modules/home-manager/core/default.nix modules/home-manager/browser/default.nix \
  modules/home-manager/coding/default.nix modules/home-manager/terminal/default.nix \
  modules/home-manager/socialMedia/default.nix
rmdir modules/home-manager/terminal/tmux
```

- [ ] **Step 2: Update the two renamed references**

In `profiles/home-manager/desktop-dev.nix`, change:

```nix
      outputs.homeManagerModules.hyprland
```

to:

```nix
      outputs.homeManagerModules.windowManager.hyprland
```

In `profiles/home-manager/wsl.nix`, change:

```nix
      outputs.homeManagerModules.core.home
```

to:

```nix
      outputs.homeManagerModules.core.homeConfig
```

In `flake/modules/exports.nix`, change:

```nix
    homeManagerModules = import ../../modules/home-manager;
```

to:

```nix
    homeManagerModules = registry ../../modules/home-manager;
```

(The top-level `modules/home-manager/default.nix` is deleted in Step 1, so the
direct import would fail from here on; the helper takes over.)

- [ ] **Step 3: Verify the registry diff is exactly the four renames**

```bash
cd /home/deadmade/nix-configuration
export V="/tmp/claude-1000/-home-deadmade-nix-configuration/7bd72be7-131c-489d-9107-8196b43118c2/scratchpad/auto-registry"
nix eval --impure --json \
  --expr '(import /home/deadmade/nix-configuration/flake/lib/registry.nix) /home/deadmade/nix-configuration/modules/nixos' \
  --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' > "$V/after-nixos.json"
nix eval --json --apply 'ms: builtins.mapAttrs (n: v: if builtins.isAttrs v then builtins.attrNames v else "leaf") ms' '.#homeManagerModules' > "$V/after-home.json"
diff <(jq -S . "$V/before-nixos.json") <(jq -S . "$V/after-nixos.json")
diff <(jq -S . "$V/before-home.json")  <(jq -S . "$V/after-home.json")
```

Expected: nixos diff empty. Home diff shows ONLY:
- `"hyprland": "leaf"` removed; `"windowManager": ["hyprland"]` added
- in `core`: `"home"` → `"homeConfig"`
- in `coding`: `"vscode"` → `"vscodium"`
- in `terminal`: `"nixIndex"` → `"nix-index"`

Any other delta (a missing module, an extra attr) is a failure: stop and investigate before committing.

- [ ] **Step 4: Verify drvPaths are still byte-identical**

```bash
cd /home/deadmade/nix-configuration
for h in $(nix eval --raw '.#nixosConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "nixos/$h: $(nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath")"
done > "$V/after-drvs.txt"
for h in $(nix eval --raw '.#homeConfigurations' --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'); do
  echo "home/$h: $(nix eval --raw ".#homeConfigurations.\"$h\".activationPackage.drvPath")"
done >> "$V/after-drvs.txt"
diff "$V/before-drvs.txt" "$V/after-drvs.txt"
```

Expected: empty diff. If a drvPath differs, the likely cause is import-order-sensitive list merging (`builtins.attrValues` sorts by attr name, and a rename can reorder a domain's import list — the four renames above were checked to keep sort positions stable, so this should not happen). Diagnose with `nix derivation show` on both paths before assuming the helper is wrong; do not commit until identical.

- [ ] **Step 5: Run flake check**

Run: `nix flake check`
Expected: passes; informational warnings about non-standard outputs (`nixosProfiles`, `homeManagerModules`, …) are normal for this repo.

- [ ] **Step 6: Format and commit**

```bash
cd /home/deadmade/nix-configuration
alejandra profiles/home-manager/desktop-dev.nix profiles/home-manager/wsl.nix flake/modules/exports.nix
git add profiles/home-manager/desktop-dev.nix profiles/home-manager/wsl.nix flake/modules/exports.nix
git commit -m 'refactor(modules): drop hand-written registry files for auto-discovery' \
  -- profiles/home-manager/desktop-dev.nix profiles/home-manager/wsl.nix flake/modules/exports.nix \
     modules/nixos/default.nix modules/home-manager/default.nix \
     modules/nixos/core/default.nix modules/nixos/desktop/default.nix \
     modules/nixos/gaming/default.nix modules/nixos/virtualization/default.nix \
     modules/home-manager/core/default.nix modules/home-manager/browser/default.nix \
     modules/home-manager/coding/default.nix modules/home-manager/terminal/default.nix \
     modules/home-manager/socialMedia/default.nix
```

---

### Task 5: Update repo documentation (CLAUDE.md)

**Files:**
- Modify: `CLAUDE.md` (the "To add a new module" paragraph in the Architecture section)

**Interfaces:**
- Consumes: final behavior from Task 4.
- Produces: documentation matching reality. **Deliberate exception: do NOT commit** — `CLAUDE.md` already carries unrelated uncommitted edits from the user's in-flight branch work; committing the file would sweep those in. Make the edit and leave it in the working tree; report this clearly at the end.

- [ ] **Step 1: Update the module-registration paragraph**

In `CLAUDE.md`, replace:

```markdown
**To add a new module:** create the `.nix` file, register it in the domain's `default.nix`, then reference it from a profile or host. Registration is required — files are not auto-discovered.
```

with:

```markdown
**To add a new module:** create the `.nix` file under the right domain directory — it is auto-discovered by `flake/lib/registry.nix` (attr name = filename minus `.nix`; a subdirectory with a `default.nix` is imported verbatim as a single module; one without recurses into a nested registry). If a profile imports the domain via `builtins.attrValues`, a new file is live on the next rebuild — keep work-in-progress modules outside `modules/`. Reference cherry-picked modules from a profile or host as before (`outputs.nixosModules.<domain>.<name>`).
```

Also update the layering description's point 1 if it still says each domain has a `default.nix` registry (`modules/nixos/desktop/default.nix` exposes …) — rewrite that sentence to say registries are generated by `flake/lib/registry.nix` and only real module dirs (e.g. `windowManager/hyprland`, `flatpak`) keep a `default.nix`.

- [ ] **Step 2: Verify the old claim is gone**

Run: `grep -n "Registration is required" CLAUDE.md`
Expected: no matches.

- [ ] **Step 3: Do not commit (see Interfaces)**

Leave `CLAUDE.md` modified in the working tree and state in the final report: "CLAUDE.md updated but intentionally left uncommitted because it carries your unrelated in-flight edits."
