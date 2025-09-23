{ config, pkgs, ... }:

{
  imports = [
    ./modules/home-manager.nix
  ];

  # Minimal server profile - packages and basic shell config only
  # No home.username, home.homeDirectory, etc. - let servers manage their own

  home.stateVersion = "22.05";

  # Core server packages
  home.packages = with pkgs; [
    # Essential CLI tools
    fd
    ripgrep
    wget
    fzf
    bat
    jq
    tmux
    bottom
    zoxide

    # Git and version control
    git

    # File operations
    rsync

    # System utilities
    direnv
    age
    duf

    # Documentation
    tealdeer
  ];

  # Minimal ZSH configuration with useful server aliases
  programs.zsh = {
    enable = true;

    shellAliases = {
      # Git aliases (essential ones only)
      g = "git";
      gs = "git status";
      gc = "git commit -m";
      gd = "git diff";
      gco = "git checkout";
      gcob = "git checkout -b";
      gpo = "git push origin";
      gplo = "git pull origin";

      # System aliases
      cat = "bat";
      top = "btm";
      ll = "ls -lhat";
      l = "ls -lhat";
      grep = "grep --color=auto";

      # Utility aliases
      checkip = "curl ipinfo.io/ip";
    };

    # Essential ZSH configuration
    initExtra = ''
      # Direnv hook
      eval "$(direnv hook zsh)"

      # Basic history settings
      HISTSIZE=10000
      SAVEHIST=10000
      setopt EXTENDED_HISTORY
      setopt INC_APPEND_HISTORY
      setopt HIST_IGNORE_DUPS

      # Increase file descriptor limit
      ulimit -n 20000
    '';
  };

  # Enable direnv for project-specific environments
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
