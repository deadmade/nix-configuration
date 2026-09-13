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
  flags ? [],
}: let
  pname = "helium";
  version = "0.16.6.1";

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
    x86_64-linux = "sha256-T29e5QpXsFYADvSsNcti2LXqLaCUjB5mLYEnHtpxO/Q=";
    aarch64-linux = "sha256-CRVOuJhFIWZosPP+WkfCp/WbhjeWzKOA1hr9nVVmIqs=";
  };

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${suffix}.AppImage";
    sha256 = hashes.${stdenv.hostPlatform.system};
  };

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

    extraPkgs = _: [
      libva
      pipewire
      vulkan-loader
    ];

    extraInstallCommands = ''
      install -Dm444 ${contents}/${pname}.desktop -t $out/share/applications
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
