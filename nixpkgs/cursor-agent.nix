{ lib, stdenv, fetchzip, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "cursor-agent";
  version = "2026.08.11-e8db854";

  src = fetchzip {
    url = "https://downloads.cursor.com/lab/${version}/darwin/arm64/agent-cli-package.tar.gz";
    hash = "sha256-GE8cxasTUT3uo9X3wzEyN+h6/rsS22mLB8Ta9sxyuyE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # The bundle contains signed native binaries. Nix fixups would invalidate
  # their signatures and prevent them from running on macOS.
  dontFixup = stdenv.isDarwin;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/cursor-agent $out/bin
    cp -R . $out/libexec/cursor-agent/

    # Keep updates declarative: the hidden flag prevents Cursor from replacing
    # this pinned Nix-managed installation under ~/.local/share.
    makeWrapper \
      $out/libexec/cursor-agent/cursor-agent \
      $out/bin/cursor-agent \
      --add-flags --disable-auto-update

    runHook postInstall
  '';

  meta = {
    description = "Cursor coding agent for the terminal";
    homepage = "https://cursor.com/docs/cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "cursor-agent";
  };
}
