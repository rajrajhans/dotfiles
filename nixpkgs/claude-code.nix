{ lib
, buildNpmPackage
, fetchzip
, nodejs_22
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.0.23";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-0f62Ku7XcEQRelJhIzvXTK/C8R27dBlcKoarZ8OQdqY=";
  };

  npmDepsHash = "sha256-Y4q5DtzkUHbglJFCqW04xyqFxon4zfwUKWA4gMSbpHg=";

  postPatch = ''
    cat > package-lock.json <<'EOF'
${builtins.toJSON {
  name = "claude-code-npm";
  version = "1.0.0";
  lockfileVersion = 3;
  requires = true;
  packages = {
    "" = {
      name = "claude-code-npm";
      version = "1.0.0";
      license = "ISC";
      dependencies = {
        "@anthropic-ai/claude-code" = "2.0.23";
      };
    };
    "node_modules/@anthropic-ai/claude-code" = {
      version = "2.0.23";
      resolved = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.0.23.tgz";
      integrity = "sha512-DB45UskLFspHr1o+HPrcaTqwplXYlmacEn/bOfBBU8nYHwe3gRantwNlRKxq51gwolL1hURS1sZAyk2MdxDhKA==";
      bin = {
        claude = "cli.js";
      };
      engines = {
        node = ">=18.0.0";
      };
      optionalDependencies = {
        "@img/sharp-darwin-arm64" = "^0.33.5";
        "@img/sharp-darwin-x64" = "^0.33.5";
        "@img/sharp-linux-arm" = "^0.33.5";
        "@img/sharp-linux-arm64" = "^0.33.5";
        "@img/sharp-linux-x64" = "^0.33.5";
        "@img/sharp-win32-x64" = "^0.33.5";
      };
    };
  };
}}
EOF
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
