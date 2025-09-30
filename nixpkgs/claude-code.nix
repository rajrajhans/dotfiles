{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.0.1";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-LUbDPFa0lY74MBU4hvmYVntt6hVZy6UUZFN0iB4Eno8=";
  };

  npmDepsHash = "sha256-D+T/v/J9J+eK88eIv216RfxEOCxPg2OvMEs43nfR0yw=";

  postPatch = ''
    cp ${./claude-code-package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/node_modules/@anthropic-ai/${pname}
    cp -r . $out/lib/node_modules/@anthropic-ai/${pname}/

    ln -s $out/lib/node_modules/@anthropic-ai/${pname}/cli.js $out/bin/claude
    chmod +x $out/bin/claude

    runHook postInstall
  '';

  meta = {
    description = "Use Claude, Anthropic's AI assistant, right from your terminal. Claude can understand your codebase, edit files, run terminal commands, and handle entire workflows for you.";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    maintainers = [ ];
  };
}
