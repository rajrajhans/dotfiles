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
    neofetch

    # Documentation
    tealdeer
  ];

  # Enable direnv for project-specific environments
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
