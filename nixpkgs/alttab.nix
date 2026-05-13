{ lib, stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "AltTab";
  version = "6.64.0";

  src = fetchzip {
    url = "https://github.com/lwouis/alt-tab-macos/releases/download/v${version}/AltTab-${version}.zip";
    hash = "sha256-t9FfpA2zk5ycpSLcw1Z+9QpPCc6DA48LerrxSWflYx0=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -r AltTab.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "Windows-style alt-tab window switcher for macOS";
    homepage = "https://github.com/lwouis/alt-tab-macos";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.darwin;
  };
}
