{ lib, stdenv, fetchurl }:

let
  version = "0.2.93";

  platformMap = {
    aarch64-darwin = {
      upstream = "macos-aarch64";
      hash = "sha256-Kpe6Z1vZkqqbmB4ug3dkYNlPRptRDAuO/ii1DSNtdnw=";
    };
    x86_64-linux = {
      upstream = "linux-x86_64";
      hash = "sha256-Tgc407VVDzyEK8CuafRogVxjKcAIoRDQwnppTcNAETU=";
    };
  };

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  pname = "grok-build";
  inherit version;

  src = fetchurl {
    urls = [
      "https://x.ai/cli/grok-${version}-${platform.upstream}"
      "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-${platform.upstream}"
    ];
    hash = platform.hash;
  };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/grok
    ln -s grok $out/bin/agent

    runHook postInstall
  '';

  meta = {
    description = "Grok Build CLI coding agent";
    homepage = "https://x.ai/cli";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "grok";
    platforms = lib.attrNames platformMap;
  };
}
