{ config, pkgs, pkgsUnstable, lib, ... }:

{
  imports = [
    ./modules/yazi.nix
    ./modules/micro.nix
    ./modules/wakapi.nix
  ];

  home.homeDirectory = "/Users/rajrajhans";
  home.username = "rajrajhans";
  home.stateVersion = "22.05";

  programs.home-manager.enable = true;
  fonts.fontconfig.enable = true;

  home.file.".local/bin/claude".source = "${pkgs.callPackage ../claude-code.nix { }}/bin/claude";
  home.file.".local/bin/statusline.sh".source = "${pkgs.callPackage ../statusline.nix { }}/bin/statusline.sh";
  home.file.".local/bin/syscheck" = { source = ../../scripts/syscheck; executable = true; };
  home.file.".zshrc".source = ../../config/shell/zshrc;
  home.file.".gitconfig".source = ../../config/git/gitconfig;
  home.file.".gitignore".source = ../../config/git/gitignore;
  home.file.".tmux.conf".source = ../../config/shell/tmux.conf;
  home.file.".iex.exs".source = ../../config/iex.exs;
  home.file.".duti".source = ../../config/duti;

  # iTerm2 — manage the prefs plist. Requires a one-time UI toggle in
  # iTerm2: Preferences → General → "Load preferences from a custom folder",
  # pointed at ~/.config/iterm2.
  home.file.".config/iterm2/com.googlecode.iterm2.plist".source =
    ../../config/iterm2/com.googlecode.iterm2.plist;

  home.activation.duti = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.duti}/bin/duti "$HOME/.duti"
  '';

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  launchd.agents.noTunes = {
    enable = true;
    config = {
      Label = "com.github.tombonez.noTunes";
      ProgramArguments = [ "${pkgs.callPackage ../notunes.nix { }}/Applications/noTunes.app/Contents/MacOS/noTunes" ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };

  launchd.agents.syncthing = {
    enable = true;
    config = {
      Label = "com.github.xor-gate.syncthing-macosx";
      ProgramArguments = [ "${pkgs.syncthing-macos}/Applications/Syncthing.app/Contents/MacOS/Syncthing" ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };

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
    fastfetch
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
    duti

    kubectx

    llm
    vlc-bin
    syncthing-macos
    (pkgs.callPackage ../notunes.nix { })
    (pkgs.callPackage ../ccusage.nix { })
    (pkgs.callPackage ../claude-code.nix { })
    (pkgs.callPackage ../codex.nix { })
    diffnav
  ] ++ lib.optionals stdenv.isDarwin [
    coreutils
  ] ++ lib.optionals stdenv.isLinux [
  ];
}
