{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

let
  version = "0.125.0";

  platformMap = {
    aarch64-darwin = {
      npmPlatform = "darwin-arm64";
      targetTriple = "aarch64-apple-darwin";
      hash = "sha256-l+ssR9iY4mpNDv8loo9+THq9McSjVSdm3nEpBtPCMAM=";
    };
    x86_64-linux = {
      npmPlatform = "linux-x64";
      targetTriple = "x86_64-unknown-linux-musl";
      hash = "sha256-W0+Iy93irv9EG02gN5oS8ytZ4salwubLd4cTXjBFGHM=";
    };
  };

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");

  vendorSrc = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${platform.npmPlatform}.tgz";
    hash = platform.hash;
  };
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-fL4wrft2styyvjvfV+5H7/mUoyAhOG88dP6ZdnZbgmM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@openai/codex
    cp -r . $out/lib/node_modules/@openai/codex/

    cp -r ${vendorSrc}/vendor $out/lib/node_modules/@openai/codex/vendor
    chmod -R u+w $out/lib/node_modules/@openai/codex/vendor
    chmod +x $out/lib/node_modules/@openai/codex/vendor/${platform.targetTriple}/codex/codex
    chmod +x $out/lib/node_modules/@openai/codex/vendor/${platform.targetTriple}/path/rg

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/codex \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI - AI-powered code assistant";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = lib.attrNames platformMap;
    maintainers = [ ];
  };
}
