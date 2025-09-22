{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.39.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-q3NUGYRo55ykWFo2NgcuhPQRbpkN0Loou1w6ixRzRSw=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@openai/codex
    cp -r . $out/lib/node_modules/@openai/codex/

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
    maintainers = [ ];
  };
}