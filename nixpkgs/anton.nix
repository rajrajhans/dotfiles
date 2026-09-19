{ lib, stdenvNoCC, fetchurl }:

let
  # Pinned to the same google/fonts rev that nixpkgs' google-fonts uses.
  # Fetching the single TTF avoids pulling the multi-GB google/fonts tree
  # just for one family.
  rev = "5174b3333331c966c38f4355d50b03ca1c1df2f9";
in
stdenvNoCC.mkDerivation {
  pname = "anton-font";
  version = "0-unstable-2026-03-13";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/google/fonts/${rev}/ofl/anton/Anton-Regular.ttf";
    hash = "sha256-pLo6kjUOuwMdoMtHYwrEnrJlCCyhvARQRC9Kg6uUfKs=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -m 444 -D $src $out/share/fonts/truetype/Anton-Regular.ttf
    runHook postInstall
  '';

  meta = {
    description = "Anton, a condensed heavy grotesque display sans";
    homepage = "https://fonts.google.com/specimen/Anton";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
