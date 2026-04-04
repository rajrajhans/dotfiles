{ lib, stdenv, fetchFromGitHub, makeWrapper, jq }:

let
  rev = "a43ac9fc423a9bd4ed791e1264e2f3ce94848523";
in
stdenv.mkDerivation {
  pname = "fast-claude-code-statusline";
  version = "0-unstable-2025-02-17";

  src = fetchFromGitHub {
    owner = "rajrajhans";
    repo = "fast-claude-code-statusline";
    inherit rev;
    hash = "sha256-xMOQ+QjpAUj7QY+x6Q8YlYfWIizqBr2yvu8p6s+uh4c=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp statusline.sh $out/bin/statusline.sh
    chmod +x $out/bin/statusline.sh
    wrapProgram $out/bin/statusline.sh --prefix PATH : ${lib.makeBinPath [ jq ]}
    runHook postInstall
  '';

  meta = {
    description = "Lightweight status bar for Claude Code";
    homepage = "https://github.com/rajrajhans/fast-claude-code-statusline";
    license = lib.licenses.mit;
    mainProgram = "statusline.sh";
  };
}
