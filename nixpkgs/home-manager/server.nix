{ config, pkgs, ... }:

{
  imports = [
    ./modules/home-manager.nix
  ];

  # Minimal server profile - packages and basic shell config only
  # Auto-detect user and home directory from environment
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
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
    neofetch

    # Documentation
    tealdeer
  ];

  # Enable direnv for project-specific environments
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
