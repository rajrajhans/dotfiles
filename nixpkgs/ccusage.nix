{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
}:

buildNpmPackage rec {
  pname = "ccusage";
  version = "17.0.2";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-/ZR+YeGAKHMfsLFPBzhMje9btsnoMotx8DB/YPztopw=";
  };

  npmDepsHash = "sha256-yDH1epZ3wVRFcLgbZ511055wXP/4EQhCL3TcAWOyyfs=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/node_modules/${pname}
    cp -r . $out/lib/node_modules/${pname}/

    ln -s $out/lib/node_modules/${pname}/dist/index.js $out/bin/${pname}
    chmod +x $out/bin/${pname}

    runHook postInstall
  '';

  meta = {
    description = "Analyze your Claude Code token usage and costs from local JSONL files";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = lib.licenses.mit;
    mainProgram = pname;
    maintainers = [ ];
  };
}


