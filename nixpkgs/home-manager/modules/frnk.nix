{ lib, pkgs, ... }:
let
  # Frnk settings that differ from its defaults, in the shape of ~/.config/frnk/frnk.jsonc.
  # Machine-specific keys (hosts, paths) stay out of this public repo.
  settings = ../../../config/frnk/settings.json;
in
{
  # Frnk writes frnk.jsonc itself (Settings, `frnk config set`, ⌘+ in a chat) by replacing the
  # file, which would turn a symlink into a plain copy. Merge the keys in on every switch instead;
  # a running Frnk reloads the file.
  home.activation.frnkSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    frnkSettings="$HOME/.config/frnk/frnk.jsonc"
    frnkSettingsTmp="$(mktemp "$HOME/.config/frnk/.frnk.jsonc.XXXXXX" 2>/dev/null || mktemp)"
    if { cat "$frnkSettings" 2>/dev/null || echo '{}'; } \
        | ${pkgs.jq}/bin/jq --slurpfile s ${settings} '. * $s[0]' \
        > "$frnkSettingsTmp"; then
      if ! cmp -s "$frnkSettingsTmp" "$frnkSettings"; then
        run mkdir -p "$HOME/.config/frnk"
        run chmod 600 "$frnkSettingsTmp"
        run mv "$frnkSettingsTmp" "$frnkSettings"
      fi
    else
      warnEcho "Not updating $frnkSettings: it is not plain JSON (comments?)"
    fi
    rm -f "$frnkSettingsTmp"
  '';
}
