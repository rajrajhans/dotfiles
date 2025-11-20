{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.60.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/@openai/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-Xi9X2lz+1FZ1Tcp24rGXakuw3MzViHcJViGPYgokLQ4=";
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