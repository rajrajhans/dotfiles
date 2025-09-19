{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "1.0.119";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-l6H3IaCIo15OkCR+QBsZJ9lQIxEaAuUOUy/yEQtcvDI=";
  };

  npmDepsHash = "sha256-1uuJ6wn4Uniaz+U9wr/uMlq9Q6AMAZJJJIkIIuDAD1U=";

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
