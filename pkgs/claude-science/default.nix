# claude-science — run Claude on your data, locally, in your browser
# (https://claude.com/product/claude-science).
#
# Anthropic ships a single prebuilt binary per platform with no source and no
# nixpkgs entry, so we vendor it.
#
# WHY THIS DOES NOT PATCHELF (do not "fix" this — it has been tested)
# The binary is a Bun single-file executable: an ELF with the JS bundle and
# assets appended after the image, located at *absolute* file offsets recorded
# in a trailer. Rewriting the ELF layout invalidates those offsets, and the
# failure is silent: the binary still starts, but degrades into a bare Bun
# runtime, so `--version` prints Bun's 1.3.13 instead of claude-science's
# 0.1.25. autoPatchelfHook did exactly that here (shrinking the file by 2688
# bytes). Measured, for the record: `--set-interpreter` on its own happened to
# leave the payload readable, but it still resizes the file, so treat any
# patchelf pass as unsafe rather than relying on that. Stripping corrupts it
# the same way. Hence dontPatchELF/dontStrip plus the byte-identity check.
#
# So the interpreter stays /lib64/ld-linux-x86-64.so.2, which on NixOS is
# supplied by nix-ld (programs.nix-ld.enable, set unconditionally in
# modules/nixos/core/packages.nix). That makes this package depend on a
# system-level toggle rather than being self-contained — the deliberate
# trade-off for keeping the payload intact. An FHS wrapper would also work but
# is the wrong tool here: it would sandbox the filesystem away from a program
# whose purpose is reading your local data.
#
# UPDATING — read this when the build fails with a hash mismatch.
# Upstream publishes no version manifest, only the binaries themselves, so
# `src` deliberately points at the mutable `latest/` URL with a pinned hash.
# A hash mismatch is therefore not corruption: it is the release signal.
#   1. nix store prefetch-file --hash-type sha256 \
#        https://downloads.claude.ai/claude-science/latest/linux-x64
#   2. Put that hash in `hash` below.
#   3. Run the fetched store path with `--version` and put the number in
#      `version` below (reporting-only; the URL ignores it).
# Immutable per-version URLs exist (.../<version>/linux-x64) if you ever want
# reproducible old commits at the cost of losing the mismatch signal.
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
}: let
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
  stdenv.mkDerivation {
    pname = "claude-science";
    version = "0.1.25";

    src = fetchurl {
      url = "https://downloads.claude.ai/claude-science/latest/linux-x64";
      hash = "sha256-xmM2e7x+xU59HlqRAllKnnCATtUHD1180RF+Zl48N2w=";
    };

    # `src` is a bare ELF executable, not an archive.
    dontUnpack = true;

    # Both of these would corrupt the appended Bun payload. See above.
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [makeWrapper];

    # Two hard runtime deps, both fatal at startup if missing. bubblewrap is the
    # agent sandbox (its only alternative being --dangerously-no-sandbox, which
    # grants full $HOME read/write and unrestricted network); socat bridges the
    # sandbox's network egress. Upstream expects both from the distro — they are
    # the only two the binary names in "Install it with: apt-get install ..."
    # messages — so shipping them here is what makes the package self-contained.
    #
    # `bash` is here for a NixOS-specific reason. The sandbox bind-mounts a fixed
    # FHS list — /usr /lib /lib64 /bin /sbin /opt /nix — which notably includes
    # /nix but NOT /run. Resolved off a normal NixOS PATH, `bash` is
    # /run/current-system/sw/bin/bash, so every sandboxed command dies with
    # `bwrap: execvp /run/current-system/sw/bin/bash: No such file or directory`
    # (this breaks the conda-backed Python/R MCP envs while the daemon itself
    # still starts). Putting a /nix/store bash first on PATH puts the real
    # interpreter inside a bound prefix; verified to take the error count to 0.
    # coreutils is here for the same reason: the sandbox probe execs a bare
    # `true`, resolved through PATH *inside* the namespace, so it has to come
    # from a bound prefix too.
    #
    # The two --run lines fix the same /run-is-not-bound problem for nix-ld
    # itself. NixOS exports NIX_LD=/run/current-system/sw/share/nix-ld/lib/ld.so;
    # inside the sandbox that path does not exist, so nix-ld aborts with
    # `[nix-ld] FATAL: panicked ... Posix(2)` (ENOENT) and *every* bundled MCP
    # env — biomart, variants, expression, rna, … — fails to create while the
    # daemon itself still comes up healthy. Both variables are symlinks into
    # /nix/store, so canonicalising them at launch lands them inside the bound
    # prefix. Resolving at runtime rather than baking in a store path keeps this
    # following programs.nix-ld.libraries across system generations.
    #
    # A shell wrapper is safe here where patchelf is not: it renames rather than
    # rewrites, so the payload is untouched and /proc/self/exe still resolves to
    # the intact ELF in libexec. A *binary* wrapper (makeBinaryWrapper) would
    # break it — /proc/self/exe would resolve to the wrapper.
    installPhase = ''
      runHook preInstall

      install -Dm755 $src $out/libexec/claude-science

      makeWrapper $out/libexec/claude-science $out/bin/claude-science \
        --prefix PATH : ${lib.makeBinPath [bubblewrap socat bash coreutils]} \
        --run 'if [ -n "''${NIX_LD:-}" ]; then export NIX_LD="$(${coreutils}/bin/readlink -f "$NIX_LD")"; fi' \
        --run 'if [ -n "''${NIX_LD_LIBRARY_PATH:-}" ]; then export NIX_LD_LIBRARY_PATH="$(${coreutils}/bin/readlink -f "$NIX_LD_LIBRARY_PATH")"; fi'

      runHook postInstall
    '';

    # Guard the invariant: if any fixup ever mutates the binary, fail loudly at
    # build time rather than shipping a silently crippled Bun runtime.
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      cmp $src $out/libexec/claude-science \
        || (echo "claude-science: binary was modified during the build; the Bun payload is corrupt" >&2; exit 1)
      runHook postInstallCheck
    '';

    # Exposed so the three sandbox-support derivations can be built and
    # inspected on their own — `nix build .#claude-science.patchedNixLd` — which
    # is the only practical way to debug this package's namespace setup.
    passthru = {
      inherit sandboxShellShim nixLdLibraries patchedNixLd;
    };

    # `claude-science update` rewrites its own binary in place. That binary now
    # lives in /nix/store, which is read-only, so the subcommand fails by
    # design — versions are Nix's job. See the UPDATING note above.
    meta = {
      homepage = "https://claude.com/product/claude-science";
      description = "Run Claude on your data, locally, in your browser";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      maintainers = [];
      platforms = ["x86_64-linux"];
      mainProgram = "claude-science";
    };
  }
