{ config, pkgs, pkgsUnstable, lib, ... }:
{

  home.file.".local/bin/claude".source = "${pkgs.callPackage ../../claude-code.nix { }}/bin/claude";

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
    yazi
    glow
    rsync
    tmux
    vivid
    bottom
    bat
    jq
    neofetch
    tealdeer
    ffmpeg_6-full
    gifsicle
    pkgs.nerd-fonts.fira-code
    zoxide
    direnv
    git
    git-open
    gh
    lazygit
    nmap

    nodejs_20
    nodePackages.eslint_d
    nodePackages.prettier
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
    age
    just

    kubectx

    llm
    vlc-bin
    syncthing-macos
    (pkgs.callPackage ../../ccusage.nix { })
    (pkgs.callPackage ../../claude-code.nix { })
    (pkgs.callPackage ../../codex.nix { })
  ] ++ lib.optionals stdenv.isDarwin [
    coreutils
  ] ++ lib.optionals stdenv.isLinux [
  ];
}
