{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

let
  version = "0.133.0";

  platformMap = {
    aarch64-darwin = {
      npmPlatform = "darwin-arm64";
      targetTriple = "aarch64-apple-darwin";
      hash = "sha256-QJNrSiMfm7X4iNB0Q8794X3Ze7a5S7DDh7o9uE965lk=";
    };
    x86_64-linux = {
      npmPlatform = "linux-x64";
      targetTriple = "x86_64-unknown-linux-musl";
      hash = "sha256-4T6OEZP6lIXTOmYCEUk77C1bjAgaGE2U+S+aCpef2vI=";
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
    hash = "sha256-jiSDnU998XGd8t5kqrH1A1yGut/4davaGi335Aypw68=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@openai/codex
    cp -r . $out/lib/node_modules/@openai/codex/

    cp -r ${vendorSrc}/vendor $out/lib/node_modules/@openai/codex/vendor
    chmod -R u+w $out/lib/node_modules/@openai/codex/vendor
    chmod +x $out/lib/node_modules/@openai/codex/vendor/${platform.targetTriple}/bin/codex
    chmod +x $out/lib/node_modules/@openai/codex/vendor/${platform.targetTriple}/codex-path/rg

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
