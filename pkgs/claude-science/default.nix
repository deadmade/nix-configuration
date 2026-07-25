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

    # Nothing to do at build time: the binary is installed as-is and the wrapper
    # is a shell script written by hand. makeWrapper cannot express this — the
    # bwrap argv embeds store paths from two derivations and has to resolve $HOME
    # and $PWD fresh on every launch.
    nativeBuildInputs = [];

    # A shell wrapper is safe here where patchelf is not: it renames rather than
    # rewrites, so the payload is untouched. The final exec is
    # `bwrap -- $out/libexec/claude-science`, so /proc/self/exe still resolves to
    # the intact ELF. A *binary* wrapper (makeBinaryWrapper) would break that —
    # /proc/self/exe would resolve to the wrapper.
    #
    # bubblewrap is also claude-science's own agent sandbox (its only alternative
    # being --dangerously-no-sandbox, which grants full $HOME read/write and
    # unrestricted network); socat bridges the sandbox's network egress. Those
    # are the only two the binary names in "Install it with: apt-get install ..."
    # messages. procps and ripgrep are needed by its process and search helpers.
    #
    # The heredoc is unquoted, so two escaping layers stack. Store paths use
    # ${"\${...}"} (Nix interpolates); runtime shell variables are written \$NAME
    # (backslash is literal in a Nix '' string, and the heredoc turns \$ into $);
    # $out is expanded by the heredoc at build time. Never write a bare
    # ${"\${"} for a shell construct — Nix would interpolate it. That is why the
    # LD_LIBRARY_PATH logic below is an if/else rather than ${"\${VAR:+...}"}.
    #
    # Backticks are command substitution here too, evaluated at build time — even
    # inside what looks like a shell comment. Keep them out of the heredoc
    # entirely; an unescaped pair silently deletes the text between them.
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

      # /bin is shadowed with a tmpfs because NixOS /bin holds only sh, but MCP
      # connectors launched by claude-science's Python bridge invoke
      # "bwrap ... /bin/bash". Symlinking both names covers both resolution
      # paths. (Quotes, not backticks: this heredoc is unquoted, so backticks
      # would be command substitution evaluated at build time.)
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

    # Guard the invariants: if any fixup ever mutates the binary, or the wrapper
    # loses a bind whose absence only shows up much later at runtime, fail loudly
    # at build time rather than shipping something silently crippled.
    doInstallCheck = true;
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
