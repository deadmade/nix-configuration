# Design: make `pkgs/claude-science` self-contained

Date: 2026-07-25
Status: approved, ready for implementation planning

## Problem

`pkgs/claude-science` currently ships the upstream Bun binary with a thin
`makeWrapper` shim. It works, but it is not self-contained: it depends on two
host-level facts to function.

1. `programs.nix-ld.enable = true` in `modules/nixos/core/packages.nix:20`,
   because the binary's ELF interpreter is left as
   `/lib64/ld-linux-x86-64.so.2`.
2. A system-wide `nix-ld` override in `overlays/default.nix` that repoints
   `DEFAULT_NIX_LD` at a `/nix/store` glibc, so the loader is reachable from
   inside claude-science's own bubblewrap sandboxes (which bind `/nix` but not
   `/run`).

Fix 2 is incomplete by construction. nix-ld's *library* search fallback,
`DEFAULT_NIX_LD_LIBRARY_PATH`, is a plain byte-string constant in
`src/main.rs` with no `option_env!` escape hatch, so an `overrideAttrs`
attribute cannot reach it. It still points at `/run/current-system/sw/share/nix-ld/lib`,
which is unreachable inside the sandbox. Sandboxed binaries that need only the
loader's own glibc work; anything needing further system libraries fails.

Additionally, the wrapper omits runtime dependencies upstream supplies:
`procps`, `ripgrep`, and a CA bundle that survives the inner sandbox's tmpfs
`/etc`.

## Goal

Supply every dependency from the package itself. After this change, the
package works regardless of host nix-ld configuration, and the system-wide
overlay hack is deleted.

## Reference implementation

<https://github.com/GHawk1124/claude-science-nix> (`package.nix`). The design
below is a port of its Linux path, with three deliberate deviations recorded
in "Deviations from upstream".

## Approach

Wrap the binary in an **outer bubblewrap** whose only job is to overlay
dependencies into paths that claude-science's *inner* bwrap sandboxes bind
through. The inner sandbox binds `/lib64`, `/bin`, and `/etc/ssl` wholesale
from the outer namespace, and binds `/nix`, but never `/run`. So whatever the
outer namespace places at those three paths becomes visible to micromamba
during conda env creation and to MCP server subprocesses.

The outer bwrap is an **overlay mechanism, not a security boundary**. It binds
`/` read-only and re-binds `$HOME`, `/tmp`, and `/run` writable. The real
security boundary remains claude-science's own inner bwrap, which this change
does not touch.

### Alternatives considered and rejected

- **Keep the plain wrapper, deepen the host patch.** Extend the global
  `overlays/default.nix` override to also `substituteInPlace` the
  `DEFAULT_NIX_LD_LIBRARY_PATH` literal against a bundled library farm.
  Rejected: still depends on `programs.nix-ld.enable` plus a system-wide
  overlay, so it does not meet the goal. It also rebuilds nix-ld for the whole
  system to serve one package.
- **Outer bwrap behind an opt-in flag**, defaulting to today's behaviour.
  Rejected as two code paths to maintain and test, with the default path
  staying host-dependent.

## Components

### `sandboxShellShim`

A `runCommand` symlink farm at a plain store path containing `bash`, `sh`, and
every binary from `coreutils`.

claude-science's bundled micromamba shells out to a hardcoded
`/run/current-system/sw/bin/bash`, but its bwrap invocation never binds `/run`,
so that path can never exist inside the sandbox. claude-science discovers
`bash` at runtime by scanning `PATH`, skipping whichever directory its own
internal `/bin/sh` resolves through — hence the shim must be at a *different*
store path than the one `/bin/sh` points at. `/nix` is bound wholesale, so the
shim is visible once picked up.

This replaces the current package's `--prefix PATH` with `bash` and
`coreutils`, which addresses the same problem less completely.

### `nixLdLibraries`

A symlink farm at `$out/share/nix-ld/lib/` containing every file from the
`lib/` directory of the NixOS `programs.nix-ld` default library set:

```
zlib openssl bzip2 stdenv.cc.cc curl xz libxml2 zstd attr acl libsodium
libssh util-linux
```

plus `ld.so` symlinked to `stdenv.cc.bintools.dynamicLinker`.

This is the piece the current approach structurally cannot provide. Mirroring
the NixOS default set means conda/micromamba packages find their shared library
dependencies without the host having configured `programs.nix-ld.libraries`.

### `patchedNixLd`

`nix-ld.overrideAttrs` applying both halves of the fallback fix:

- `DEFAULT_NIX_LD = "${nixLdLibraries}/share/nix-ld/lib/ld.so"` — read via
  `option_env!` at compile time (`src/main.rs:36`), so a derivation attribute
  reaches it.
- `postPatch` substituting the byte-string literal at `src/main.rs:42`:
  `b"/run/current-system/sw/share/nix-ld/lib"` → `b"${nixLdLibraries}/share/nix-ld/lib"`.

Both are needed because claude-science's sandbox env allowlist is a hardcoded
`["HOME","LOGNAME","PATH","SHELL","TERM","USER"]`, so `NIX_LD` and
`NIX_LD_LIBRARY_PATH` cannot be passed in from outside. The compile-time
defaults are the only channel.

Verified against nix-ld 2.0.6 as resolved by this flake
(`/nix/store/p6vsxnavqj38ifapyigara4gr34nacsk-source`): both the `option_env!`
fallback and the byte-string literal are present at the stated lines, and the
build output exposes `$out/libexec/nix-ld`.

### The wrapper

A hand-written `$out/bin/claude-science` replaces `makeWrapper`. It is
hand-written because the bwrap argv embeds store paths from two derivations and
must resolve `$HOME` and `$PWD` fresh on each launch.

Responsibilities, in order:

1. `export DISABLE_AUTOUPDATER=1`. `claude-science update` rewrites its own
   binary in place, which cannot work from a read-only store; disabling the
   updater is better than letting it fail at runtime.
2. Prepend `sandboxShellShim`, `bash`, `bubblewrap`, `procps`, `ripgrep`, and
   `socat` to `PATH`; prepend `stdenv.cc.cc.lib` to `LD_LIBRARY_PATH`.
3. Export `SSL_CERT_FILE` and `CURL_CA_BUNDLE` at `${cacert}/etc/ssl/certs/ca-bundle.crt`.
   The inner sandbox `--ro-bind`s `/etc/ssl` from the outer namespace, but the
   NixOS `/etc/ssl/certs/ca-certificates.crt` is a symlink through
   `/etc/static/...` that breaks inside the sandbox's tmpfs `/etc`.
4. Bypass bwrap entirely for `--version`, `-V`, `--help`, `-h`, `exec`ing the
   binary directly. This keeps the package usable where user namespaces are
   unavailable — containers, CI, and potentially `deadWsl`.
5. `exec` bwrap with the bind list below, ending in the real binary.

```
--ro-bind / /
--tmpfs /lib64
--ro-bind ${patchedNixLd}/libexec/nix-ld /lib64/ld-linux-x86-64.so.2
--tmpfs /etc/ssl/certs
--ro-bind ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
--ro-bind ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt
--tmpfs /bin
--symlink ${sandboxShellShim}/bin/sh   /bin/sh
--symlink ${sandboxShellShim}/bin/bash /bin/bash
--bind /run /run
--bind /tmp /tmp
--bind "$HOME" "$HOME"
--proc /proc
--dev-bind /dev /dev
--chdir "$PWD"
--die-with-parent
-- $out/libexec/claude-science "$@"
```

`/bin` is shadowed with a tmpfs because NixOS `/bin` contains only `sh`, while
MCP connectors launched by claude-science's Python bridge invoke
`bwrap ... /bin/bash`. Symlinking both names covers both resolution paths.

## Deviations from upstream

1. **`--dev-bind /dev /dev` instead of `--dev /dev`.** Upstream's minimal
   devtmpfs exposes no `/dev/dri` and no `/dev/nvidia*`. `hosts/deadPc/config.nix:146`
   configures an NVIDIA GPU and claude-science advertises GPU compute. Since
   `--ro-bind / /` already exposes the whole filesystem, binding real `/dev`
   costs no meaningful isolation in a namespace that is an overlay mechanism
   rather than a security boundary.

2. **`autoPatchelfHook` is not ported.** Upstream lists it in
   `nativeBuildInputs`, where it would rewrite the ELF in `$out`. This binary
   is a Bun single-file executable whose JS bundle and assets sit at absolute
   file offsets recorded in a trailer; rewriting the ELF layout invalidates
   those offsets and the failure is silent — the binary still starts but
   degrades to a bare Bun runtime, so `--version` prints Bun's version instead
   of claude-science's. This was measured previously and is documented in the
   package header. `dontPatchELF`, `dontStrip`, and the byte-identity install
   check all stay.

3. **`--replace-fail` instead of the deprecated `--replace`** in the nix-ld
   `postPatch`. A future nix-ld bump that renames or reformats the literal must
   fail the build loudly rather than silently producing a nix-ld that still
   points at `/run`.

## Removals

- The two `--run` lines that `readlink -f` `NIX_LD` and `NIX_LD_LIBRARY_PATH`.
  Once the loader inside the namespace is a store path by construction, they
  are dead weight.
- `makeWrapper` from `nativeBuildInputs`.
- The `nix-ld` block in `overlays/default.nix`, restoring
  `modifications = _final: prev:`. Its stated purpose was claude-science; with
  the fix localized to the package, keeping it would rebuild nix-ld
  system-wide for no consumer and let the two copies of the fix drift apart.

`programs.nix-ld.enable = true` in `modules/nixos/core/packages.nix:20` stays.
It is a general-purpose system setting; claude-science simply no longer depends
on it.

## Unchanged

- Platforms remain `["x86_64-linux"]`. There are no Darwin hosts, and upstream
  ships no `linux-arm64` binary, so `deadPi` (aarch64-linux) was never in
  scope. Upstream's Darwin path is therefore not ported.
- The binary stays at `$out/libexec/claude-science`. The final `exec` is
  `bwrap -- $out/libexec/claude-science`, so `/proc/self/exe` still resolves to
  the intact ELF — the property that makes a shell wrapper safe here where
  `makeBinaryWrapper` would not be.
- `src` continues to point at the mutable `latest/` URL with a pinned hash, and
  the UPDATING protocol in the header comment is preserved: a hash mismatch is
  the release signal, not corruption.
- `doInstallCheck` / `installCheckPhase` comparing `$src` byte-for-byte against
  the installed binary.

## Verification

Build-time:

- `nix build` succeeds and the `cmp` install check passes, proving no fixup
  mutated the ELF.
- The nix-ld `--replace-fail` succeeds, proving the substitution target still
  exists in the pinned nix-ld source.

Runtime, on `deadPc`:

- `claude-science --version` prints `0.1.25`, not a Bun version. A Bun version
  here is the payload-corruption signature.
- `claude-science serve` starts and the bundled MCP environments (biomart,
  variants, expression, rna) create with zero failures. This is the end-to-end
  proof that the loader, library farm, shell shim, and CA bundle all landed
  inside the inner sandbox — the previous failure mode was a healthy daemon
  with every MCP env failing to create.
- Confirm the above with the system-wide `nix-ld` overlay already reverted, so
  the result proves package self-containment rather than residual host help.

Because `deadPc` is a `nix-mineral` host, deploy with `nixos-rebuild boot` plus
a reboot so the prior generation stays bootable for rollback.

## Known limitations

- Writes outside `$HOME`, `/tmp`, and `/run` fail; the rest of the filesystem
  is readable but read-only. Accepted: data lives under `$HOME`. If an external
  drive or `/mnt` path is needed later, add a `--bind` for it.
- Startup requires user namespaces. Where they are unavailable, only the
  `--version` / `--help` bypass path works.
