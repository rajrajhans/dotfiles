{ lib, pkgs, ... }:
let
  # Keys enforced in Claude Code's user settings (~/.claude/settings.json).
  # Only for settings with no env var; those go in the wrapper in ../../claude-code.nix.
  settings = {
    # Don't compact a long conversation (>200K tokens) left idle until its prompt
    # cache is about to expire; compact manually with /compact instead.
    # https://code.claude.com/docs/en/settings-reference#idlecompaction
    idleCompaction = false;
  };
in
{
  # Claude Code writes this file itself (/config, /model, permission rules), so a
  # read-only home.file symlink would break it. Merge the keys in on every switch.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeSettings="$HOME/.claude/settings.json"
    claudeSettingsTmp="$(mktemp)"
    if { cat "$claudeSettings" 2>/dev/null || echo '{}'; } \
        | ${pkgs.jq}/bin/jq --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} '. * $s' \
        > "$claudeSettingsTmp"; then
      if ! cmp -s "$claudeSettingsTmp" "$claudeSettings"; then
        run mkdir -p "$HOME/.claude"
        run cp "$claudeSettingsTmp" "$claudeSettings"
      fi
    else
      warnEcho "Not updating $claudeSettings: it is not valid JSON"
    fi
    rm -f "$claudeSettingsTmp"
  '';
}
