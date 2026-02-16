{ lib, stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "wakapi";
  version = "2.17.1";

  src = fetchzip {
    url = "https://github.com/muety/wakapi/releases/download/${version}/wakapi_darwin_arm64.zip";
    hash = "sha256-zL3CEZLF2HRyFplo9rkZ9v+82vulOPrmSFgQQ+PmQeU=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 wakapi $out/bin/wakapi
    runHook postInstall
  '';

  meta = {
    description = "Self-hosted WakaTime-compatible backend for coding statistics";
    homepage = "https://github.com/muety/wakapi";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "wakapi";
  };
}
