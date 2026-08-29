{ lib, stdenvNoCC, fetchurl, autoPatchelfHook }:

stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  version = "1.1.22";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.1.22-5711547746615296/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-HhohmobnXXxjUfltGCyiEFMC1cNNj6nDEmXcCt8kFF8=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity $out/bin/agy

    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity CLI";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
