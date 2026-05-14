{ lib, buildNpmPackage, nodejs_22, makeWrapper }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.73.1";

  src = ./pi;

  npmDepsHash = "sha256-K0PdAtr16EFXGrlPGbNKaJTfgCC1OwdTgfZ62HvZkXQ=";

  nodejs = nodejs_22;

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/pi
    cp -r node_modules $out/lib/pi/node_modules
    cp package.json $out/lib/pi/package.json

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/pi \
      --add-flags "$out/lib/pi/node_modules/@mariozechner/pi-coding-agent/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Pi coding agent — minimal terminal coding harness";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = nodejs_22.meta.platforms;
  };
}
