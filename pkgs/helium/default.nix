# Helium — private, fast, Chromium-based browser (https://helium.computer).
# Not in nixpkgs yet, so we package imputnet's prebuilt AppImage ourselves via
# appimageTools.wrapType2, which runs it in an FHS sandbox instead of patchelfing
# every binary by hand. Bump `version` + `hashes` from the helium-linux releases
# page (see ./update.sh).
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  makeFontsConf,
  xdg-utils,
  coreutils,
  libva,
  pipewire,
  vulkan-loader,
  noto-fonts-cjk-sans,
  noto-fonts-cjk-serif,
  # Extra command-line flags baked into the wrapper.
  flags ? [],
}: let
  pname = "helium";
  version = "0.16.5.1";

  suffix =
    {
      aarch64-linux = "arm64";
      x86_64-linux = "x86_64";
    }
    .${
      stdenv.hostPlatform.system
    }
    or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  hashes = {
    x86_64-linux = "sha256-N6+wwg46ufsbCqEJv/WpTWDCnI3tnFt58cG6TsGxXew=";
    aarch64-linux = "sha256-zCZFBLbG/3pdeBx6qBrVWy4deNNtbu4EK9RTL9wgTQQ=";
  };

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${suffix}.AppImage";
    sha256 = hashes.${stdenv.hostPlatform.system};
  };

  # Same args wrapType2 extracts with internally, so this resolves to that very
  # derivation rather than unpacking a second time.
  contents = appimageTools.extract {inherit pname version src;};

  fontsConf = makeFontsConf {
    fontDirectories = [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;

    nativeBuildInputs = [makeWrapper];

    # The AppImage excludelist already covers the usual X/GL libraries; these are
    # ones Chromium dlopens at runtime for hardware video and Wayland.
    extraPkgs = _: [
      libva
      pipewire
      vulkan-loader
    ];

    extraInstallCommands = ''
      install -Dm444 ${contents}/${pname}.desktop -t $out/share/applications
      # Upstream ships a bare `Exec=helium` (plus one per desktop action); point
      # them all at the wrapper so the entry works without ${pname} on $PATH.
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=${pname}' "Exec=$out/bin/${pname}"
      cp -r ${contents}/usr/share/icons $out/share

      wrapProgram $out/bin/${pname} \
        --prefix PATH : ${lib.makeBinPath [xdg-utils coreutils]} \
        --set-default CHROME_VERSION_EXTRA nix \
        --set FONTCONFIG_FILE "${fontsConf}" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}" \
        ${lib.concatMapStringsSep " \\\n    " (f: "--add-flags \"${f}\"") flags}
    '';

    meta = {
      homepage = "https://helium.computer";
      description = "Private, fast, and honest web browser based on Chromium";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      maintainers = [];
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = pname;
    };
  }
