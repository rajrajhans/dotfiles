{ lib, stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "AltTab";
  # Do NOT downgrade below 11.x. 6.64.0 silently closed Chrome app-shim windows
  # (Slack/WhatsApp `app_mode_loader`) via its Accessibility polling on macOS 26,
  # and every pre-11.x release binary is now 404 on GitHub (unfetchable).
  version = "11.4.4";

  src = fetchzip {
    url = "https://github.com/lwouis/alt-tab-macos/releases/download/v${version}/AltTab-${version}.zip";
    # Take this from the `got:` line of a failing build -- `nix-prefetch-url --unpack`
    # produces a hash fetchzip rejects.
    hash = "sha256-aF5xrPJ8SVp/LgyOg9U37pXojaosVQUl1OOJjiyAYSE=";
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
