{ lib, stdenvNoCC, fetchzip }:

# Packaged rather than `pi install`ed so the version is pinned in git instead of
# in ~/.pi/agent/settings.json, which is machine-local state pi rewrites itself.
# The npm tarball ships a prebuilt ./dist and has no runtime deps (pi satisfies
# the peer deps), so there is nothing to build.
stdenvNoCC.mkDerivation rec {
  pname = "pi-provider-litellm";
  version = "2.2.1";

  src = fetchzip {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-akED0cyEMVoLvgvnMYzKfQxIBEe3Uzjv1IuQJ9WkXDw=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${pname}
    cp -r dist package.json $out/lib/${pname}/

    runHook postInstall
  '';

  meta = {
    description = "LiteLLM proxy provider extension for the pi coding agent";
    homepage = "https://github.com/balcsida/pi-provider-litellm";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
