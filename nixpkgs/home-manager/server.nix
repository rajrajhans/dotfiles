{ config, pkgs, ... }:

{
  imports = [
    ./modules/home-manager.nix
  ];

  # Server-specific user config - edit these values for your server
  home.username = "user";
  home.homeDirectory = "/home/user";
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

    # Development tools
    claude-code
    python3
    nodejs

    # Media utilities
    yt-dlp
    ffmpeg
  ];

  # Enable direnv for project-specific environments
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}