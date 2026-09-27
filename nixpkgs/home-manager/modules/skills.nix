{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in {
  home.packages = [
    (pkgs.writeShellScriptBin "skills" ''
      exec ${python}/bin/python3 ${../../../scripts/skills} "$@"
    '')
  ];
  home.shellAliases.sk = "skills";
}
