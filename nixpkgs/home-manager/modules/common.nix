{ config, pkgs, pkgsUnstable, ... }:
{

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  # programs.zsh.enable = true;

  home.packages = with pkgs; [
    fd
    ripgrep
    zsh
    wget
    fzf
    glow
    rsync
    tmux
    vivid
    bottom
    bat
    jq
    neofetch
    tealdeer
    gh
    ffmpeg_5-full
    gifsicle
    (nerdfonts.override { fonts = [ "FiraCode" ]; })

    nodejs-18_x
    nodePackages.eslint_d
    nodePackages.prettier
    nodePackages.live-server
    nodePackages.tailwindcss
    nodePackages.ts-node

    rustc
    cargo
    rustfmt

    yt-dlp
    delta
    git-lfs

    tokei
    yarn

    gum
    duf

    nixpkgs-fmt

    awscli2
    caddy

    rclone
    k9s
    rar
    imagemagick
  ] ++ lib.optionals stdenv.isDarwin [
    coreutils
  ] ++ lib.optionals stdenv.isLinux [
  ];
}
