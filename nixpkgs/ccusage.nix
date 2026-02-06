{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
}:

buildNpmPackage rec {
  pname = "ccusage";
  version = "18.0.5";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-i4UyRU7EA0PLduABnPGbcD8I06ZjmjwXCC77vtFM638=";
  };

  npmDepsHash = "sha256-yejRRB3mJRoov8ntT9/Q8bL3ilZcnHE1y767E3V/4LY=";

  postPatch = ''
    cat > package-lock.json <<'EOF'
${builtins.toJSON {
  name = "ccusage";
  lockfileVersion = 3;
  requires = true;
  packages = {
    "" = {
      dependencies = {
        ccusage = "^${version}";
      };
    };
    "node_modules/ccusage" = {
      version = version;
      resolved = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
      integrity = "sha512-bnZrVbGm5h7hIIOH3FZFaDxKgJLLHhWDWIv7/9M6/O373YM6RAwsG9hxZXA1ep+C2ISiNEX6MYVoXgkoSuFf9Q==";
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


