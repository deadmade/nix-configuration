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
  sandboxShellShim = runCommand "claude-science-sandbox-shell-shim" {} ''
    mkdir -p $out/bin
    ln -s ${bash}/bin/bash $out/bin/bash
    ln -s ${bash}/bin/sh $out/bin/sh
    for f in ${coreutils}/bin/*; do
      ln -s "$f" "$out/bin/$(basename "$f")"
    done
  '';

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
    version = "0.1.27";

    src = fetchurl {
      url = "https://downloads.claude.ai/claude-science/latest/linux-x64";
      hash = "sha256-LjGLL18NHVSwQizXPqR7zJTHP3GzV9NhRFSifd0tm6o=";
    };

    dontUnpack = true;

    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [];

    installPhase = ''
            runHook preInstall

            install -Dm755 $src $out/libexec/claude-science
            mkdir -p $out/bin

            cat > $out/bin/claude-science <<WRAPPER
      #!${bash}/bin/bash
      export DISABLE_AUTOUPDATER=1

      export PATH="${lib.makeBinPath [sandboxShellShim bash bubblewrap procps ripgrep socat]}:\$PATH"

      if [ -n "\$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [stdenv.cc.cc.lib]}:\$LD_LIBRARY_PATH"
      else
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [stdenv.cc.cc.lib]}"
      fi

      export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export CURL_CA_BUNDLE="${cacert}/etc/ssl/certs/ca-bundle.crt"

      case "\$1" in
        --version|-V|--help|-h)
          exec $out/libexec/claude-science "\$@"
          ;;
      esac

      exec ${bubblewrap}/bin/bwrap \\
        --ro-bind / / \\
        --tmpfs /lib64 \\
        --ro-bind ${patchedNixLd}/libexec/nix-ld /lib64/ld-linux-x86-64.so.2 \\
        --unsetenv NIX_LD \\
        --unsetenv NIX_LD_LIBRARY_PATH \\
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

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      cmp $src $out/libexec/claude-science \
        || (echo "claude-science: binary was modified during the build; the Bun payload is corrupt" >&2; exit 1)

      grep -q '${patchedNixLd}/libexec/nix-ld' $out/bin/claude-science \
        || (echo "claude-science: wrapper does not bind the patched nix-ld" >&2; exit 1)

      grep -q -- '--dev-bind /dev /dev' $out/bin/claude-science \
        || (echo "claude-science: wrapper lost --dev-bind; GPU device nodes would be hidden" >&2; exit 1)

      grep -q -- '--unsetenv NIX_LD' $out/bin/claude-science \
        || (echo "claude-science: wrapper lost --unsetenv NIX_LD; the host NIX_LD would override the bundled loader and every MCP env would fail to create" >&2; exit 1)

      runHook postInstallCheck
    '';

    passthru = {
      inherit sandboxShellShim nixLdLibraries patchedNixLd;
    };

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
