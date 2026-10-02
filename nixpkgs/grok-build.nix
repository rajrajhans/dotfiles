{ lib, stdenv, fetchurl }:

let
  version = "1.0.46";

  platformMap = {
    aarch64-darwin = {
      upstream = "macos-aarch64";
      hash = "sha256-6NqjAjZMnDtqVUbVEc+9GrXl1AepsEKC9mBmXqQF+fM=";
    };
    x86_64-linux = {
      upstream = "linux-x86_64";
      hash = "sha256-QWJqUykjJBQLklVrnUL/VULj3NBK/4Xq+4aJ3UrbRPw=";
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
