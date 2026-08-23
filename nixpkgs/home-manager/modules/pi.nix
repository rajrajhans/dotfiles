{ config, lib, pkgs, ... }:

let
  defaultTools = [
    "read"
    "grep"
    "find"
    "ls"
    "bash"
    "edit"
    "write"
  ];
  defaultToolsJson = builtins.toJSON defaultTools;
  settingsPath = "${config.home.homeDirectory}/.pi/agent/settings.json";
in
{
  # Pi owns the rest of this mutable file. Merge only the managed default-tool
  # field so model, theme, provider, and package changes survive HM switches.
  home.activation.piDefaultTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_path=${lib.escapeShellArg settingsPath}
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$settings_path")"
    settings_tmp="$(${pkgs.coreutils}/bin/mktemp "''${settings_path}.tmp.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$settings_tmp"' EXIT

    if [ -f "$settings_path" ]; then
      ${pkgs.jq}/bin/jq --argjson defaultTools '${defaultToolsJson}' \
        '.defaultTools = $defaultTools' "$settings_path" > "$settings_tmp"
    else
      ${pkgs.jq}/bin/jq -n --argjson defaultTools '${defaultToolsJson}' \
        '{ defaultTools: $defaultTools }' > "$settings_tmp"
    fi

    ${pkgs.coreutils}/bin/chmod 600 "$settings_tmp"
    ${pkgs.coreutils}/bin/mv "$settings_tmp" "$settings_path"
    trap - EXIT
  '';
}
