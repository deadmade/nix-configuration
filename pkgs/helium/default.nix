# Helium — private, fast, Chromium-based browser (https://helium.computer).
# Not in nixpkgs yet, so we package imputnet's prebuilt .deb ourselves:
# extract it, patchelf the ELF binaries onto Nix libraries, and wrap with
# wrapGAppsHook for desktop/GTK integration (same approach nixpkgs uses for
# Brave/Chrome). Bump `version` + `hashes` from the helium-linux releases page.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  makeWrapper,
  wrapGAppsHook3,
  makeFontsConf,
  qt6,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  adwaita-icon-theme,
  nss,
  nspr,
  libGL,
  libgbm,
  libdrm,
  libxkbcommon,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libXrender,
  libxcb,
  libxshmfence,
  libXi,
  libXcursor,
  libXft,
  libXScrnSaver,
  libXtst,
  libSM,
  libICE,
  alsa-lib,
  dbus,
  cups,
  ffmpeg,
  libva,
  pipewire,
  wayland,
  vulkan-loader,
  systemd,
  xdg-utils,
  coreutils,
  pango,
  cairo,
  gdk-pixbuf,
  atk,
  at-spi2-atk,
  at-spi2-core,
  freetype,
  fontconfig,
  libuuid,
  expat,
  zlib,
  libxml2,
  libkrb5,
  snappy,
  udev,
  libXt,
  binutils,
  noto-fonts-cjk-sans,
  noto-fonts-cjk-serif,
  # Extra command-line flags baked into the wrapper.
  flags ? [],
}: let
  pname = "helium";
  version = "0.13.6.1";

  suffix =
    {
      aarch64-linux = "arm64";
      x86_64-linux = "amd64";
    }
    .${
      stdenv.hostPlatform.system
    }
    or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  hashes = {
    x86_64-linux = "sha256-ms+XG5/zl4lfrdgxTuCfOyfHQCeGUav+orzI680FxDE=";
    aarch64-linux = "sha256-lFNhrzWow2ChadSuQqMzFgGKEnZJMOgiGg/RCtmh1OE=";
  };

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-bin_${version}-1_${suffix}.deb";
    sha256 = hashes.${stdenv.hostPlatform.system};
  };

  inherit (lib) makeLibraryPath makeSearchPathOutput makeBinPath;

  deps = [
    stdenv.cc.cc
    nss
    nspr
    libGL
    libgbm
    libdrm
    libxkbcommon
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libXrender
    libxcb
    libxshmfence
    libXi
    libXcursor
    libXft
    libXScrnSaver
    libXtst
    libSM
    libICE
    alsa-lib
    dbus
    cups
    ffmpeg
    libva
    pipewire
    wayland
    vulkan-loader
    systemd
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    freetype
    fontconfig
    libuuid
    expat
    zlib
    libxml2
    gtk3
    glib
    libXt
    libkrb5
    snappy
    udev
  ];

  libPath =
    makeLibraryPath deps
    + lib.optionalString stdenv.hostPlatform.is64bit
    (":" + makeSearchPathOutput "lib" "lib64" deps)
    + ":$out/opt/helium";

  fontsConf = makeFontsConf {
    fontDirectories = [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [
      patchelf
      makeWrapper
      wrapGAppsHook3
      qt6.wrapQtAppsHook
      dpkg
      binutils
    ];

    dontWrapQtApps = true;

    buildInputs = [
      glib
      gsettings-desktop-schemas
      gtk3
      gtk4
      adwaita-icon-theme
      qt6.qtbase
      qt6.qtwayland
      libXt
      libkrb5
      snappy
      udev
      systemd
    ];

    unpackPhase = ''
      runHook preUnpack
      ar vx $src
      tar -xvf data.tar.xz
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out $out/bin $out/opt

      cp -r opt/helium $out/opt/helium
      cp -r usr/share $out/share

      # Patch main binaries onto the Nix dynamic linker + library path.
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${libPath}" \
        $out/opt/helium/helium

      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${libPath}" \
        $out/opt/helium/helium_crashpad_handler

      # Patch shared libraries that need it.
      for lib in $out/opt/helium/libEGL.so $out/opt/helium/libGLESv2.so; do
        if [ -f "$lib" ]; then
          patchelf --set-rpath "${libPath}" "$lib" || true
        fi
      done

      # Point the upstream wrapper at the absolute binary path.
      substituteInPlace $out/opt/helium/helium-wrapper \
        --replace-fail '$HERE/helium' "$out/opt/helium/helium"

      # Symlink for wrapGAppsHook to wrap (same trick nixpkgs' Brave uses).
      ln -sf $out/opt/helium/helium-wrapper $out/bin/helium

      # Fix the .desktop entry.
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-fail 'Exec=helium' "Exec=$out/bin/helium" \
        --replace-fail 'Icon=helium' "Icon=$out/share/icons/hicolor/256x256/apps/helium.png"

      mkdir -p $out/share/icons/hicolor/256x256/apps
      if [ -f $out/opt/helium/product_logo_256.png ]; then
        cp $out/opt/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png
      elif [ -f $out/opt/helium/product_logo.png ]; then
        cp $out/opt/helium/product_logo.png $out/share/icons/hicolor/256x256/apps/helium.png
      fi

      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${libPath}"
        --prefix PATH : ${lib.makeBinPath [xdg-utils coreutils]}
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
        --set-default CHROME_VERSION_EXTRA nix
        --set FONTCONFIG_FILE "${fontsConf}"
        ${lib.concatMapStringsSep "\n      " (f: "--add-flags \"${f}\"") flags}
      )
    '';

    meta = {
      homepage = "https://helium.computer";
      description = "Private, fast, and honest web browser based on Chromium";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      maintainers = [];
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "helium";
    };
  }
