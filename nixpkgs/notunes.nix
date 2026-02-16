{ lib, stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "noTunes";
  version = "3.5";

  src = fetchzip {
    url = "https://github.com/tombonez/noTunes/releases/download/v${version}/noTunes-${version}.zip";
    hash = "sha256-IQyFgLeDotrHoODqxbtvAqUt47DbIcHhIcBqaoabY4Q=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -r noTunes.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "Simple macOS application that prevents Apple Music from launching";
    homepage = "https://github.com/tombonez/noTunes";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
