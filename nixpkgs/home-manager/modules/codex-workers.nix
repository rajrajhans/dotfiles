{ config, pkgs, ... }:
let
  # Live checkout, not the store copy: edits to the skill or bridge take effect
  # without a rebuild. See config/claude/skills/codex-workers/README.md.
  skillDir = "${config.home.homeDirectory}/dotfiles/config/claude/skills/codex-workers";
in
{
  # Let any Claude Code session start Codex workers and talk to them.
  home.file.".claude/skills/codex-workers".source =
    config.lib.file.mkOutOfStoreSymlink skillDir;

  home.packages = [
    (pkgs.writeShellScriptBin "codex-bridge" ''
      exec ${pkgs.python3}/bin/python3 -I ${skillDir}/bridge.py "$@"
    '')
  ];
}
