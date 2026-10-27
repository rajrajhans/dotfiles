{ lib, stdenv, fetchurl, autoPatchelfHook }:

let
  version = "0.1.1";

  platformMap = {
    aarch64-darwin = {
      upstream = "universal2-apple-darwin";
      hash = "sha256-qIgwuvnAQCyFD0tqG5G4gCMsNmvRsJKp53y+z7M563c=";
    };
    x86_64-linux = {
      upstream = "x86_64-unknown-linux-gnu";
      hash = "sha256-HyjmPBneoVe4sZ17FzFb7dJ4gB5FeGesiMzDdvlaSvI=";
    };
  };

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  pname = "invideo-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/invideoio/cli/releases/download/v${version}/invideo-${platform.upstream}.tar.gz";
    hash = platform.hash;
  };

  sourceRoot = ".";

  # The Linux build links against the system glibc loader.
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  dontBuild = true;

  # The macOS binary is ad-hoc signed. Nix fixups would invalidate the
  # signature and prevent it from running.
  dontFixup = stdenv.isDarwin;

  # `invideo update` only rewrites script installs; for anything else it just
  # prints a hint, so it can't clobber this pinned store copy.
  installPhase = ''
    runHook preInstall

    install -Dm755 invideo $out/bin/invideo

    runHook postInstall
  '';

  meta = {
    description = "invideo CLI: edit NLE timelines and generate media from the terminal";
    homepage = "https://github.com/invideoio/cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "invideo";
    platforms = lib.attrNames platformMap;
  };
}
