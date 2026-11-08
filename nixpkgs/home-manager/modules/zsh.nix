{ pkgs, ... }:

# The zsh layer config/shell/zshrc expects: oh-my-zsh, its custom plugins, the
# powerlevel10k theme and its config, and atuin's config. Shared by mbp (which
# links the zshrc as ~/.zshrc) and box (which links it as ~/.zshrc.local).
{
  # Provide oh-my-zsh as a read-only symlink into the nix store.
  # ZSH_COMPDUMP is overridden in zshrc to keep the completion cache writable.
  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  # OMZ custom plugins sourced from nixpkgs. ZSH_CUSTOM in zshrc points
  # at ~/.oh-my-zsh-custom and OMZ loads each plugin from plugins/<name>/.
  home.file.".oh-my-zsh-custom/plugins/fast-syntax-highlighting".source =
    "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting";
  home.file.".oh-my-zsh-custom/plugins/zsh-autosuggestions".source =
    "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions";

  # atuin config — shell history database & search (replaces the old
  # zsh-fzf-history-search and per-directory-history OMZ plugins).
  home.file.".config/atuin/config.toml".source = ../../../config/atuin/config.toml;

  # Powerlevel10k as an OMZ custom theme. ZSH_THEME="powerlevel10k/powerlevel10k"
  # resolves to $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme.
  home.file.".oh-my-zsh-custom/themes/powerlevel10k".source =
    "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
  home.file.".p10k.zsh".source = ../../../config/shell/p10k.zsh;
}
