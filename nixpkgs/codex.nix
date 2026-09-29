{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

let
  version = "0.159.0";

  platformMap = {
    aarch64-darwin = {
      npmPlatform = "darwin-arm64";
      targetTriple = "aarch64-apple-darwin";
      hash = "sha256-jEq4AD8nqFihRYPTNGYLKXeOkb4Mxp4UgjvzkgBPmsM=";
    };
    x86_64-linux = {
      npmPlatform = "linux-x64";
      targetTriple = "x86_64-unknown-linux-musl";
      hash = "sha256-5sW9wgQgR7cf0TzJOU9/1YfdJEUK9B4yblM4MTx/wCA=";
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
    hash = "sha256-QshYrLX47oz/vDg0AqBq9czCnoNhqRwW94w3fzzrJE8=";
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
