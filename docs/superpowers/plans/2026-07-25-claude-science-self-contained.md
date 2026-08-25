# claude-science Self-Contained Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `pkgs/claude-science` supply every runtime dependency itself, so it no longer relies on the host's `programs.nix-ld` configuration or on a system-wide `nix-ld` overlay.

**Architecture:** Wrap the upstream Bun binary in an outer bubblewrap namespace whose only job is to overlay dependencies at the three paths claude-science's *inner* bwrap sandboxes bind through: `/lib64` (a patched nix-ld pointing at bundled store paths), `/bin` (a bash + coreutils shim), and `/etc/ssl/certs` (a real CA bundle). The outer namespace is an overlay mechanism, not a security boundary — `/` is bound read-only and `$HOME`, `/tmp`, `/run`, `/dev` are re-bound. The real boundary stays claude-science's own inner bwrap, which is untouched.

**Tech Stack:** Nix (flake-parts), `stdenv.mkDerivation`, `runCommand` symlink farms, `nix-ld` 2.0.6 (`overrideAttrs` + `substituteInPlace`), `bubblewrap`.

**Spec:** `docs/superpowers/specs/2026-07-25-claude-science-self-contained-design.md`

## Global Constraints

- **Never patch or strip the binary.** `dontPatchELF = true` and `dontStrip = true` stay. Do **not** add `autoPatchelfHook` even though the upstream reference uses it — it rewrites the ELF and silently corrupts the appended Bun payload (the binary still starts but degrades to a bare Bun runtime).
- **Never use `makeBinaryWrapper`.** The final `exec` must land on the real ELF so `/proc/self/exe` resolves to it.
- **Platforms stay `["x86_64-linux"]`.** Do not port the upstream Darwin path — there are no Darwin hosts and upstream ships no `linux-arm64` binary.
- **Do not change `version`, `src`, or the `hash`.** They stay at `0.1.25` / `sha256-xmM2e7x+xU59HlqRAllKnnCATtUHD1180RF+Zl48N2w=` with the mutable `latest/` URL. The UPDATING comment block in the file header is preserved verbatim.
- **Leave `programs.nix-ld.enable = true`** in `modules/nixos/core/packages.nix:20` alone. It is a general-purpose system setting; the package just stops depending on it.
- **Commit messages must be Conventional Commits** — `convco` runs as a pre-commit hook and will reject anything else.
- **`alejandra` runs as a pre-commit hook.** Run `nix fmt` before committing or the hook will rewrite files under you.

### Nix string-escaping rules for the wrapper heredoc (Task 2)

Task 2 writes a shell script from inside a Nix `''` string via an *unquoted*
heredoc. Two layers of escaping apply and getting them wrong produces a wrapper
that fails only at runtime. The rules:

| You want in the final script | Write this in the `.nix` file | Why |
|---|---|---|
| a store path | `${bash}` | Nix interpolates `${...}` |
| runtime shell var `$HOME` | `\$HOME` | `\` is literal in Nix `''`; the heredoc turns `\$` into `$` |
| build-time expansion of `$out` | `$out` | no `{`, so Nix ignores it; the heredoc expands it |
| a line continuation | `\\` at end of line | heredoc turns `\\` into `\`, which bash reads as a continuation |

**Never write `${` inside the heredoc body for a shell construct** — Nix will
try to interpolate it. This is why the `LD_LIBRARY_PATH` logic below uses an
`if`/`else` rather than `${VAR:+...}`.

**Never put backticks inside the heredoc body, including in shell comments.**
An unquoted heredoc treats them as command substitution and evaluates them at
build time, silently replacing the text between them with the command's output.
This was hit during execution: a comment reading ``# `bwrap ... /bin/bash`. …``
came out of the build as `# . …`. Use double quotes for inline code instead.
Nix comments *outside* the heredoc are unaffected — backticks are fine there.

---

### Task 1: Add the three helper derivations

Adds `sandboxShellShim`, `nixLdLibraries`, and `patchedNixLd` to the package and exposes them via `passthru` so each can be built and inspected on its own. Nothing consumes them yet — the wrapper is still the current `makeWrapper` one, so the package keeps working throughout this task.

The `passthru` block is intentional and permanent, not scaffolding. These three derivations are the fiddly part of this package; being able to `nix build .#claude-science.patchedNixLd` and inspect it is the only practical way to debug it later.

**Files:**
- Modify: `pkgs/claude-science/default.nix` (function arguments, new `let` block, new `passthru`)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, for Task 2:
  - `sandboxShellShim` — derivation with `bin/bash`, `bin/sh`, and all of `coreutils` as symlinks
  - `nixLdLibraries` — derivation with `share/nix-ld/lib/` holding every `.so` from the nix-ld default set plus `ld.so`
  - `patchedNixLd` — derivation whose `libexec/nix-ld` is a nix-ld built with both compile-time defaults pointing at `nixLdLibraries`

- [ ] **Step 1: Replace the function argument list**

The current argument list is at `pkgs/claude-science/default.nix:38-47`. Replace it in full. Note `makeWrapper` is **kept for now** — Task 2 removes it, so the package still builds at the end of this task.

```nix
{
  lib,
  stdenv,
  runCommand,
  fetchurl,
  makeWrapper,
  bubblewrap,
  bash,
  coreutils,
  procps,
  ripgrep,
  socat,
  cacert,
  nix-ld,
  zlib,
  openssl,
  bzip2,
  curl,
  xz,
  libxml2,
  zstd,
  attr,
  acl,
  libsodium,
  libssh,
  util-linux,
}:
```

- [ ] **Step 2: Insert the `let` block between the arguments and `stdenv.mkDerivation`**

The file currently reads `}:` immediately followed by `stdenv.mkDerivation {`. Insert this between them, so it becomes `}:\nlet ... in\nstdenv.mkDerivation {`.

```nix
let
  # claude-science's bundled micromamba shells out to a hardcoded
  # /run/current-system/sw/bin/bash, but its bwrap invocation never binds /run,
  # so that path can never exist inside the sandbox. It discovers `bash` at
  # runtime by scanning PATH, skipping whichever directory its own internal
  # /bin/sh resolves through — so the shim has to live at a *different* store
  # path than the one /bin/sh points at. /nix is bound wholesale, so the shim
  # is reachable once picked up.
  sandboxShellShim = runCommand "claude-science-sandbox-shell-shim" {} ''
    mkdir -p $out/bin
    ln -s ${bash}/bin/bash $out/bin/bash
    ln -s ${bash}/bin/sh $out/bin/sh
    for f in ${coreutils}/bin/*; do
      ln -s "$f" "$out/bin/$(basename "$f")"
    done
  '';

  # Mirrors the default library set of the NixOS programs.nix-ld module, so
  # conda/micromamba packages find their shared libraries inside the sandbox
  # without the host having configured programs.nix-ld.libraries.
  baseLibraries = [
    zlib
    openssl
    bzip2
    stdenv.cc.cc
    curl
    xz
    libxml2
    zstd
    attr
    acl
    libsodium
    libssh
    util-linux
  ];

  nixLdLibraries =
    runCommand "claude-science-nix-ld-libraries" {
      libPaths = map (p: "${lib.getLib p}") baseLibraries;
    } ''
      mkdir -p $out/share/nix-ld/lib
      for pkg in $libPaths; do
        if [ -d "$pkg/lib" ]; then
          for f in "$pkg"/lib/*; do
            ln -sf "$f" "$out/share/nix-ld/lib/"
          done
        fi
      done
      ln -sf ${stdenv.cc.bintools.dynamicLinker} $out/share/nix-ld/lib/ld.so
    '';

  # nix-ld has two independent fallbacks, both baked in at compile time and
  # both pointing at /run/current-system/sw/share/nix-ld — unreachable from
  # inside a sandbox that binds /nix but not /run. Both must be redirected,
  # because claude-science's sandbox env allowlist is a hardcoded
  # ["HOME","LOGNAME","PATH","SHELL","TERM","USER"], so neither NIX_LD nor
  # NIX_LD_LIBRARY_PATH can be passed in from outside.
  #
  #   - DEFAULT_NIX_LD (the loader) is read via option_env! at src/main.rs:36,
  #     so a derivation attribute reaches it.
  #   - DEFAULT_NIX_LD_LIBRARY_PATH (the library search path) is a plain
  #     byte-string constant at src/main.rs:42 with no escape hatch, so it has
  #     to be substituted in the source.
  #
  # --replace-fail, not --replace: if a future nix-ld renames or reformats that
  # literal, this must fail the build rather than silently produce a nix-ld
  # that still points at /run.
  patchedNixLd = nix-ld.overrideAttrs (old: {
    DEFAULT_NIX_LD = "${nixLdLibraries}/share/nix-ld/lib/ld.so";
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/main.rs \
          --replace-fail \
          'b"/run/current-system/sw/share/nix-ld/lib"' \
          'b"${nixLdLibraries}/share/nix-ld/lib"'
      '';
  });
in
```

- [ ] **Step 3: Add the `passthru` block**

Insert immediately before the `meta = {` block (currently at `pkgs/claude-science/default.nix:125`).

```nix
  # Exposed so the three sandbox-support derivations can be built and
  # inspected on their own — `nix build .#claude-science.patchedNixLd` — which
  # is the only practical way to debug this package's namespace setup.
  passthru = {
    inherit sandboxShellShim nixLdLibraries patchedNixLd;
  };
```

- [ ] **Step 4: Format**

```bash
cd /home/deadmade/nix-configuration && nix fmt
```

- [ ] **Step 5: Verify the package still builds unchanged**

```bash
cd /home/deadmade/nix-configuration && nix build .#claude-science --no-link --print-out-paths
```

Expected: succeeds. Because the wrapper is untouched, the output path must be **identical** to the one built before this task. If it changed, something other than `passthru` was modified — `passthru` does not affect the derivation hash.

- [ ] **Step 6: Verify the shell shim**

```bash
cd /home/deadmade/nix-configuration
nix build .#claude-science.sandboxShellShim --no-link --print-out-paths
SHIM=$(nix eval --raw .#claude-science.sandboxShellShim)
"$SHIM/bin/bash" --version | head -1
"$SHIM/bin/true" && echo "coreutils ok"
```

Expected: a GNU bash version line, then `coreutils ok`. Both `bash` and `sh` must exist in `$SHIM/bin`.

- [ ] **Step 7: Verify the library farm**

```bash
cd /home/deadmade/nix-configuration
LIBS=$(nix build .#claude-science.nixLdLibraries --no-link --print-out-paths)
ls -l "$LIBS/share/nix-ld/lib/ld.so"
ls "$LIBS/share/nix-ld/lib/" | grep -E '^lib(ssl|z|curl|xml2|zstd)\.so' | head
```

Expected: `ld.so` is a symlink into a glibc store path ending `/lib/ld-linux-x86-64.so.2`, and the grep lists several `libssl.so*`, `libz.so*`, `libcurl.so*` entries. An empty listing means `baseLibraries` resolved to packages without a `lib/` output.

- [ ] **Step 8: Verify the patched nix-ld actually got both patches**

This is the important check of the task — the substitution is the half that the previous overlay approach could not do at all.

```bash
cd /home/deadmade/nix-configuration
LIBS=$(nix eval --raw .#claude-science.nixLdLibraries)
NIXLD=$(nix build .#claude-science.patchedNixLd --no-link --print-out-paths)
strings "$NIXLD/bin/nix-ld" | grep -F "$LIBS/share/nix-ld/lib"
```

Expected: at least one match — the bundled library path is compiled into the binary. Zero matches means the `substituteInPlace` and/or `DEFAULT_NIX_LD` did not take effect, and the whole design fails silently at runtime. Do not proceed past this step without a match.

If the build fails with a `substituteInPlace` error saying the pattern was not found, nix-ld has changed upstream: open `$(nix eval --raw .#claude-science.patchedNixLd.src)/src/main.rs`, find the current `DEFAULT_NIX_LD_LIBRARY_PATH` literal, and update the `--replace-fail` pattern to match.

- [ ] **Step 9: Commit**

```bash
cd /home/deadmade/nix-configuration
git add pkgs/claude-science/default.nix
git commit -m "feat(claude-science): add bundled nix-ld, library farm and shell shim"
```

---

### Task 2: Replace the wrapper with the outer bubblewrap

Swaps `makeWrapper` for a hand-written wrapper that `exec`s bubblewrap. This is the task that makes the package self-contained.

**Files:**
- Modify: `pkgs/claude-science/default.nix` (header comment, `nativeBuildInputs`, `installPhase`, `installCheckPhase`)

**Interfaces:**
- Consumes: `sandboxShellShim`, `nixLdLibraries`, `patchedNixLd` from Task 1.
- Produces: `$out/bin/claude-science` (wrapper) and `$out/libexec/claude-science` (untouched ELF).

**Re-read the escaping table in Global Constraints before writing the heredoc.**

- [ ] **Step 1: Replace the stale part of the header comment**

The block currently at `pkgs/claude-science/default.nix:19-25` claims the package depends on a system-level nix-ld toggle. That stops being true in this task. Replace those lines — starting at `# So the interpreter stays ...` and ending at `# whose purpose is reading your local data.` — with:

```
# The interpreter therefore stays /lib64/ld-linux-x86-64.so.2. Rather than
# depend on the host's nix-ld for that path, the wrapper below starts an outer
# bubblewrap namespace and binds its own patched nix-ld over it, alongside a
# bash/coreutils shim at /bin and a real CA bundle at /etc/ssl/certs. Those are
# exactly the three paths claude-science's *inner* sandboxes bind through, so
# whatever lands there is visible to micromamba during conda env creation and
# to MCP server subprocesses.
#
# The outer namespace is an overlay mechanism, not a security boundary: / is
# bound read-only and $HOME, /tmp, /run and /dev are re-bound, so the program
# can still read your data — which is its whole purpose. The actual boundary is
# claude-science's own inner bwrap, untouched here.
#
# --dev-bind /dev /dev rather than --dev /dev, deliberately: a minimal devtmpfs
# hides /dev/dri and /dev/nvidia*, and claude-science does GPU compute. Since
# --ro-bind / / already exposes the filesystem, binding real /dev costs no
# isolation that this namespace was providing.
```

Leave the `WHY THIS DOES NOT PATCHELF` and `UPDATING` blocks exactly as they are.

- [ ] **Step 2: Drop `makeWrapper` from the argument list and `nativeBuildInputs`**

Remove the `makeWrapper,` line from the function arguments added in Task 1, and replace the `nativeBuildInputs` line with:

```nix
  # Nothing to do at build time: the binary is installed as-is and the wrapper
  # is a shell script written by hand. makeWrapper cannot express this — the
  # bwrap argv embeds store paths from two derivations and has to resolve $HOME
  # and $PWD fresh on every launch.
  nativeBuildInputs = [];
```

- [ ] **Step 3: Replace the `installPhase` in full**

Replace everything from `installPhase = ''` through its closing `'';` (currently `pkgs/claude-science/default.nix:99-110`), including the long comment block above it at lines 66-98 — that comment described the old `makeWrapper` approach and is now wrong.

This deletes the two `--run` lines that `readlink -f` `NIX_LD` and `NIX_LD_LIBRARY_PATH` (lines 106-107). That is intended, not an oversight: once the loader inside the namespace is a store path by construction, canonicalising the host's env vars accomplishes nothing. Do not carry them over.

The heredoc body sits at column 0 on purpose: Nix strips the *common* leading whitespace from a `''` string, and the heredoc terminator `WRAPPER` must end up at column 0.

```nix
  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/libexec/claude-science
    mkdir -p $out/bin

    cat > $out/bin/claude-science <<WRAPPER
#!${bash}/bin/bash
# claude-science rewrites its own binary in place on update, which cannot work
# from a read-only store. Versions are Nix's job; see the UPDATING note.
export DISABLE_AUTOUPDATER=1

export PATH="${lib.makeBinPath [sandboxShellShim bash bubblewrap procps ripgrep socat]}:\$PATH"

if [ -n "\$LD_LIBRARY_PATH" ]; then
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [stdenv.cc.cc.lib]}:\$LD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [stdenv.cc.cc.lib]}"
fi

# The inner sandbox --ro-binds /etc/ssl from the outer namespace, but NixOS
# routes /etc/ssl/certs/ca-certificates.crt through a /etc/static symlink that
# dangles inside the sandbox's tmpfs /etc. Point at the real bundle.
export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
export CURL_CA_BUNDLE="${cacert}/etc/ssl/certs/ca-bundle.crt"

# These need no sandbox, and skipping bwrap keeps them working where user
# namespaces are unavailable — containers, CI, some WSL kernels. Without this
# bypass those environments fail with "bwrap: setting up uid map: Permission
# denied" before printing anything.
case "\$1" in
  --version|-V|--help|-h)
    exec $out/libexec/claude-science "\$@"
    ;;
esac

exec ${bubblewrap}/bin/bwrap \\
  --ro-bind / / \\
  --tmpfs /lib64 \\
  --ro-bind ${patchedNixLd}/libexec/nix-ld /lib64/ld-linux-x86-64.so.2 \\
  --tmpfs /etc/ssl/certs \\
  --ro-bind ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt \\
  --ro-bind ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt \\
  --tmpfs /bin \\
  --symlink ${sandboxShellShim}/bin/sh /bin/sh \\
  --symlink ${sandboxShellShim}/bin/bash /bin/bash \\
  --bind /run /run \\
  --bind /tmp /tmp \\
  --bind "\$HOME" "\$HOME" \\
  --proc /proc \\
  --dev-bind /dev /dev \\
  --chdir "\$PWD" \\
  --die-with-parent \\
  -- \\
  $out/libexec/claude-science "\$@"
WRAPPER

    chmod +x $out/bin/claude-science

    runHook postInstall
  '';
```

Why `/bin` is shadowed with a tmpfs: NixOS `/bin` holds only `sh`, but MCP connectors launched by claude-science's Python bridge invoke `bwrap ... /bin/bash`. Symlinking both names covers both resolution paths.

- [ ] **Step 4: Extend the install check**

Replace the existing `installCheckPhase` (currently `pkgs/claude-science/default.nix:115-120`). The `cmp` guard is unchanged; the two `grep` guards are new, and catch a wrapper that builds fine but is missing a bind that only fails much later at runtime.

```nix
  installCheckPhase = ''
    runHook preInstallCheck

    cmp $src $out/libexec/claude-science \
      || (echo "claude-science: binary was modified during the build; the Bun payload is corrupt" >&2; exit 1)

    grep -q '${patchedNixLd}/libexec/nix-ld' $out/bin/claude-science \
      || (echo "claude-science: wrapper does not bind the patched nix-ld" >&2; exit 1)

    grep -q -- '--dev-bind /dev /dev' $out/bin/claude-science \
      || (echo "claude-science: wrapper lost --dev-bind; GPU device nodes would be hidden" >&2; exit 1)

    runHook postInstallCheck
  '';
```

- [ ] **Step 5: Format and build**

```bash
cd /home/deadmade/nix-configuration && nix fmt && nix build .#claude-science --no-link --print-out-paths
```

Expected: succeeds, all three install checks pass. A failure on the `cmp` check means a fixup hook mutated the ELF — do not work around it by relaxing the check.

- [ ] **Step 6: Verify the payload is intact via the bypass path**

```bash
cd /home/deadmade/nix-configuration
OUT=$(nix eval --raw .#claude-science)
"$OUT/bin/claude-science" --version
```

Expected: `0.1.25`. A Bun version number (e.g. `1.3.13`) here is the payload-corruption signature and means something patched or stripped the binary. This exercises the bwrap bypass, so it proves nothing about the sandbox yet — that is Task 4.

- [ ] **Step 7: Inspect the generated wrapper by eye**

```bash
cd /home/deadmade/nix-configuration
cat "$(nix eval --raw .#claude-science)/bin/claude-science"
```

Check specifically: `$HOME`, `$PWD`, `$1`, `$@`, `$PATH`, `$LD_LIBRARY_PATH` appear as bare shell variables (**not** as `\$HOME`), all other paths are `/nix/store/...`, and the `bwrap` invocation ends with a line continuation on every line but the last. Any literal `\$` in the file means the escaping table was misread.

- [ ] **Step 8: Commit**

```bash
cd /home/deadmade/nix-configuration
git add pkgs/claude-science/default.nix
git commit -m "feat(claude-science): supply all runtime deps via an outer bwrap overlay"
```

---

### Task 3: Revert the system-wide nix-ld overlay

The `nix-ld` override in `overlays/default.nix` exists solely for claude-science. With the fix now local to the package, keeping it rebuilds nix-ld system-wide for no consumer and lets two copies of the same fix drift apart.

**Files:**
- Modify: `overlays/default.nix` (remove the `nix-ld` block, restore `_final`)

**Interfaces:**
- Consumes: a self-contained `pkgs/claude-science` from Task 2.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Record the pre-revert state**

This is the measurement that makes the next steps meaningful. Run it *before* editing.

**Attribute paths matter here, and two obvious ones are wrong.**
`nixosConfigurations.deadPc.pkgs` does **not** carry the custom packages:
`modules/nixos/core/defaults.nix:3-6` applies only `unstable-packages` and
`modifications`, not `additions`. The overlaid set that actually contains
`claude-science` is the Home Manager one, which applies
`builtins.attrValues outputs.overlays` (`modules/home-manager/core/nixConfig.nix:11`).

```bash
cd /home/deadmade/nix-configuration
printf 'home overlaid : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.claude-science.outPath'; echo
printf 'flake package : '; nix eval --raw '.#packages.x86_64-linux.claude-science.outPath'; echo
printf 'patchedNixLd  : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.claude-science.passthru.patchedNixLd.outPath'; echo
printf 'system nix-ld : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.nix-ld.outPath'; echo
```

Expected: the two claude-science paths are **already identical**, and the
system nix-ld is the *overlaid* one (distinct from stock). Note all four values.

Why identical rather than divergent: the package's own `patchedNixLd` sets
`DEFAULT_NIX_LD` explicitly, which fully masks the value the overlay supplies.
So claude-science never actually consumed the overlay — which is precisely what
the revert is asserting, and it is demonstrable before touching anything.

- [ ] **Step 2: Remove the `nix-ld` block**

In `overlays/default.nix`, delete the entire `nix-ld = prev.nix-ld.overrideAttrs (_: { ... });` attribute together with the comment block above it (everything from `# nix-ld falls back to a compile-time default loader path ...` down to the closing `});`).

- [ ] **Step 3: Restore the unused-argument marker**

The `final` argument was introduced only for that block. Change the overlay's head back:

```nix
  modifications = _final: prev: {
```

Leave the `logiops` override untouched.

- [ ] **Step 4: Format and verify the revert changed nothing for claude-science**

```bash
cd /home/deadmade/nix-configuration && nix fmt overlays/default.nix
printf 'home overlaid : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.claude-science.outPath'; echo
printf 'flake package : '; nix eval --raw '.#packages.x86_64-linux.claude-science.outPath'; echo
printf 'patchedNixLd  : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.claude-science.passthru.patchedNixLd.outPath'; echo
printf 'system nix-ld : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.nix-ld.outPath'; echo
```

Expected, against the Step 1 values:

- both claude-science paths **unchanged** and still identical to each other — this is the proof of self-containment, since removing the overlay had no effect on the package
- `patchedNixLd` **unchanged**
- system nix-ld **changed**, from the overlaid build to stock — confirming the overlay really was removed and the test above is not vacuous

If claude-science's path moved, it was consuming the overlay after all and Task 2 is incomplete.

- [ ] **Step 5: Check the flake still evaluates**

```bash
cd /home/deadmade/nix-configuration && nix flake check 2>&1 | tail -20
```

Expected: no errors. Informational warnings about the custom `nixosProfiles` / `homeManagerModules` outputs are expected and pre-existing — ignore those.

- [ ] **Step 6: Build the reverted package**

```bash
cd /home/deadmade/nix-configuration && nix build .#claude-science --no-link --print-out-paths
```

Expected: succeeds, install checks pass, and the path matches Step 4.

- [ ] **Step 7: Commit**

```bash
cd /home/deadmade/nix-configuration
git add overlays/default.nix
git commit -m "refactor(overlays): drop nix-ld override now that claude-science bundles its own"
```

---

### Task 4: Deploy and verify end-to-end on deadPc

Everything so far proves the derivation is *shaped* right. Only a real run proves the loader, library farm, shell shim, and CA bundle actually land inside claude-science's inner sandbox. The previous failure mode was specifically a healthy-looking daemon with every bundled MCP environment failing to create, so "it starts" is not evidence.

**Files:**
- Modify: none (deployment and verification only)

**Interfaces:**
- Consumes: the completed package from Tasks 1-3.
- Produces: nothing.

- [ ] **Step 1: Deploy**

`deadPc` is a `nix-mineral` (hardened) host, so use `boot` + reboot rather than `switch` — that keeps the prior generation bootable for rollback.

```bash
cd /home/deadmade/nix-configuration
sudo nixos-rebuild boot --flake .#deadPc
```

Then reboot, and after coming back up:

```bash
cd /home/deadmade/nix-configuration && nhs
```

- [ ] **Step 2: Confirm the deployed binary is the real one**

```bash
which claude-science
claude-science --version
```

Expected: a `/nix/store/...` or `~/.nix-profile/...` path, and version `0.1.25` — not a Bun version.

- [ ] **Step 3: Confirm the sandbox path starts at all**

```bash
claude-science serve
```

Expected: the daemon starts and prints its web UI URL. A `bwrap: setting up uid map: Permission denied` here means user namespaces are unavailable on this host, which would need investigating before anything else — the `--version` check above deliberately bypasses bwrap, so it cannot catch this.

- [ ] **Step 4: The actual acceptance test — bundled MCP environments**

With `serve` running, exercise the bundled MCP environments (biomart, variants, expression, rna) from the web UI, and watch the daemon's output.

Expected: **zero** environment-creation failures. The specific failures this change exists to eliminate, any of which means the fix did not land:

| Error | What it means failed |
|---|---|
| `[nix-ld] FATAL: panicked ... Posix(2)` | `patchedNixLd` is not being bound over `/lib64/ld-linux-x86-64.so.2` |
| `error while loading shared libraries: lib*.so` | `nixLdLibraries` is missing that library, or the `substituteInPlace` did not take |
| `bwrap: execvp .../bash: No such file or directory` | `sandboxShellShim` is not on the inner `PATH`, or `/bin/bash` was not symlinked |
| TLS / certificate verification errors | the `cacert` binds or `SSL_CERT_FILE` are not reaching the sandbox |

- [ ] **Step 5: Confirm the result is not residual host help**

The overlay revert in Task 3 must already be deployed for Step 4 to prove anything. Confirm the running system carries it:

```bash
cd /home/deadmade/nix-configuration
git log --oneline -3
printf 'system nix-ld : '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.nix-ld.outPath'; echo
printf 'bundled nix-ld: '; nix eval --raw '.#homeConfigurations."deadmade@deadPc".pkgs.claude-science.passthru.patchedNixLd.outPath'; echo
```

Expected: the overlay-revert commit is in the log, and the two nix-ld paths **differ** — the system nix-ld is stock, the one claude-science uses is patched. If they were the same, the overlay is still in play and Step 4 proved nothing.

Also confirm the running system is actually the built one, since the whole point is that the *deployed* claude-science carries the bundled nix-ld:

```bash
grep -o '/nix/store/[a-z0-9]*-nix-ld-[^/]*' "$(readlink -f "$(which claude-science)")" | head -1
```

Expected: the bundled `patchedNixLd` path, matching `bundled nix-ld` above.

- [ ] **Step 6: Confirm data access still works**

The outer bwrap makes everything outside `$HOME`, `/tmp`, `/run` and `/dev` read-only. Verify that does not get in the way: from the UI, read a data file under `$HOME` and write a result next to it.

Expected: both succeed. A write failure outside `$HOME` is expected and documented; a write failure *inside* `$HOME` means the `--bind "$HOME" "$HOME"` line is wrong.

- [ ] **Step 7: Confirm GPU device nodes are visible**

This is what `--dev-bind` buys over upstream's `--dev`, so verify it rather than assuming.

```bash
claude-science exec -- ls /dev/nvidiactl /dev/dri 2>&1 || \
  echo "check manually from the UI: run 'ls /dev/nvidiactl /dev/dri' in a kernel"
```

Expected: the device nodes are listed. `No such file or directory` means `--dev-bind` was not applied — but the install check in Task 2 should already have caught that, so investigate the wrapper rather than the runtime.

- [ ] **Step 8: Record the outcome**

No commit is required for this task. Report which of Steps 2-7 passed, with the actual output. If any step failed, report the exact error text rather than a summary — the error strings in Step 4's table map directly onto which component to fix.

---

## Rollback

If any task's verification fails and the cause is not obvious, each task is a single commit touching one file, so `git revert <sha>` restores the previous working state. On a deployed system, `deadPc` keeps the prior generation bootable because Task 4 uses `nixos-rebuild boot`; select it from the boot menu.
