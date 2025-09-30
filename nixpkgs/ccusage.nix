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
    cat > package-lock.json <<'EOF'
${builtins.toJSON {
  name = "ccusage";
  lockfileVersion = 3;
  requires = true;
  packages = {
    "" = {
      dependencies = {
        ccusage = "^16.2.2";
      };
    };
    "node_modules/ccusage" = {
      version = "16.2.2";
      resolved = "https://registry.npmjs.org/ccusage/-/ccusage-16.2.2.tgz";
      integrity = "sha512-ZPtS3KTBG6aUSyCcHoaqnT+ChfGEUKBaROpRCkm0j2GOLuq2ZgPJ9Up+oWfj1Szsd6M57CGG+OmGP1O71nvCYA==";
      license = "MIT";
      bin = {
        ccusage = "dist/index.js";
      };
      engines = {
        node = ">=20.19.4";
      };
      funding = {
        url = "https://github.com/ryoppippi/ccusage?sponsor=1";
      };
    };
  };
}}
EOF
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


