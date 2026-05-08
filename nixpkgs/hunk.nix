{ lib
, stdenv
, fetchzip
, nodejs_22
, makeWrapper
}:

let
  version = "0.10.0";

  platformMap = {
    aarch64-darwin = {
      npmPlatform = "darwin-arm64";
      hash = "sha256-LW+wOmh32a86zulfoTAe2BZgE5MnOC2F6SRrLn/rKLw=";
    };
    x86_64-linux = {
      npmPlatform = "linux-x64";
      hash = "sha256-luSKW73utCGHi+kotEanRy81ffH6l54oitohPB1quKE=";
    };
  };

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");

  binarySrc = fetchzip {
    url = "https://registry.npmjs.org/hunkdiff-${platform.npmPlatform}/-/hunkdiff-${platform.npmPlatform}-${version}.tgz";
    hash = platform.hash;
  };
in
stdenv.mkDerivation {
  pname = "hunk";
  inherit version;

  src = fetchzip {
    url = "https://registry.npmjs.org/hunkdiff/-/hunkdiff-${version}.tgz";
    hash = "sha256-2+7qPpP83uJWjWLTH7pJyzd9Ez7mgfARS2TJ+zjPxHo=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/hunkdiff
    cp -r . $out/lib/node_modules/hunkdiff/

    install -Dm755 ${binarySrc}/bin/hunk $out/libexec/hunk

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/hunk \
      --add-flags "$out/lib/node_modules/hunkdiff/bin/hunk.cjs" \
      --set HUNK_BIN_PATH "$out/libexec/hunk"

    runHook postInstall
  '';

  meta = {
    description = "Review-first terminal diff viewer for agentic coders";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = lib.attrNames platformMap;
  };
}
