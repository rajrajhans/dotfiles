{ lib, pkgs, ... }:
let
  # Keys enforced in Claude Code's user settings (~/.claude/settings.json).
  # Only for settings with no env var; those go in the wrapper in ../../claude-code.nix.
  settings = {
    # Don't compact a long conversation (>200K tokens) left idle until its prompt
    # cache is about to expire; compact manually with /compact instead.
    # https://code.claude.com/docs/en/settings-reference#idlecompaction
    idleCompaction = false;
    # No Co-Authored-By trailer, PR attribution line or session link.
    # https://code.claude.com/docs/en/settings-reference#attribution
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
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

  # `attribution` stops Claude Code adding the trailer, but not the model copying one from a
  # repo's history. Keep this rule in ~/.claude/CLAUDE.md as a marked block, so the rest of
  # the file stays editable (Claude's /memory writes there too).
  home.activation.claudeCodeMemory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeMemory="$HOME/.claude/CLAUDE.md"
    claudeMemoryTmp="$(mktemp)"
    {
      if [ -f "$claudeMemory" ]; then
        ${pkgs.gnused}/bin/sed '/^<!-- dotfiles:begin -->$/,/^<!-- dotfiles:end -->$/d' "$claudeMemory"
      fi
      cat ${../../../config/claude/CLAUDE.dotfiles.md}
    } > "$claudeMemoryTmp"
    if ! cmp -s "$claudeMemoryTmp" "$claudeMemory"; then
      run mkdir -p "$HOME/.claude"
      run cp "$claudeMemoryTmp" "$claudeMemory"
    fi
    rm -f "$claudeMemoryTmp"
  '';
}
