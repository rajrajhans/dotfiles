{ lib, pkgs, ... }:

# A Linux dev box whose base shell setup is owned by another tool (it writes
# ~/.zshrc, ~/.zprofile and ~/.config/direnv/direnvrc, and loads nix-direnv
# there). This is the server config plus the zsh layer, kept out of
# the files that tool owns: the zshrc goes to ~/.zshrc.local, which its
# ~/.zshrc sources last.
let
  # Copied as a plain file, not linked into the store, so it is still there when
  # a box comes back on a fresh /nix and every home-manager link is dangling.
  hmRestore = pkgs.writeText "hm-restore" ''
    #!/usr/bin/env bash
    # Re-apply the box home-manager config, e.g. after /nix was replaced.
    set -euo pipefail
    flake="''${HM_RESTORE_FLAKE:-$HOME/.dotfiles-raj}"
    out="$(nix build --no-link --print-out-paths --impure "$flake#homeConfigurations.box.activationPackage")"
    HOME_MANAGER_BACKUP_EXT=hm-bak "$out/activate"
  '';
  # setup_nix.sh reads this, so a plain run here re-applies this config and not
  # the Linux default, which would unlink the zsh layer and link ~/.bashrc.
  profilePin = pkgs.writeText "nix-profile" "box\n";
in
{
  imports = [
    ./server.nix
    ./modules/zsh.nix
  ];

  # The box tooling writes ~/.config/direnv/direnvrc itself (with nix-direnv) and
  # edits ~/.profile and ~/.bashrc in place; a read-only home-manager link at any
  # of them makes it fail. The box's shell is zsh, so bash needs nothing here.
  programs.direnv.enable = lib.mkForce false;
  programs.direnv.nix-direnv.enable = lib.mkForce false;
  programs.bash.enable = lib.mkForce false;

  home.file.".zshrc.local".source = ../../config/shell/zshrc;

  # Used by config/shell/zshrc; the server config has the rest.
  # tailscale and socat: the box joins the tailnet in userspace mode (no TUN).
  home.packages = with pkgs; [
    atuin
    vivid
    tailscale
    socat
  ];

  home.activation.hmRestore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm755 ${hmRestore} "$HOME/.local/bin/hm-restore"
    run install -Dm644 ${profilePin} "''${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/nix-profile"
  '';
}
