{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libgcc,
}: let
  pname = "ai-usagebar";
  version = "1.16.0";

  suffix =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "aarch64";
    }
    .${
      stdenv.hostPlatform.system
    }
    or (throw "${pname}: unsupported system ${stdenv.hostPlatform.system}");

  hashes = {
    x86_64-linux = "sha256-lT8FRZJozi//GX0JZ6pyovq6Is2z7qGYJiiAgcTGHnI=";
    aarch64-linux = "sha256-87Hb1/6V2sVQxmqYac6CabS7RdAFPQix8c4N4EY6Y8E=";
  };
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/akitaonrails/ai-usagebar/releases/download/v${version}/ai-usagebar-linux-${suffix}.tar.gz";
      hash = hashes.${stdenv.hostPlatform.system};
    };

    sourceRoot = ".";

    nativeBuildInputs = [autoPatchelfHook];

    buildInputs = [libgcc];

    installPhase = ''
      runHook preInstall
      install -Dm755 ai-usagebar     "$out/bin/ai-usagebar"
      install -Dm755 ai-usagebar-tui "$out/bin/ai-usagebar-tui"
      install -Dm644 config.example.toml \
        "$out/share/doc/${pname}/config.example.toml"
      install -Dm644 LICENSE "$out/share/licenses/${pname}/LICENSE"
      runHook postInstall
    '';

    meta = {
      description = "CLI reporting AI plan usage, quota resets and consumption pace";
      homepage = "https://github.com/akitaonrails/ai-usagebar";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "ai-usagebar";
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
