{ lib, stdenv, fetchFromGitHub, makeWrapper, jq }:

let
  rev = "9a17b67a6e2950ef9363d49b6d4456de3f170c1a";
in
stdenv.mkDerivation {
  pname = "fast-claude-code-statusline";
  version = "0-unstable-2026-07-16";

  src = fetchFromGitHub {
    owner = "rajrajhans";
    repo = "fast-claude-code-statusline";
    inherit rev;
    hash = "sha256-jb+nQsS4v+GS7bB3SnpUy0E1/1JeUTV3ULoYbEhgGNQ=";
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
