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

  # Provide oh-my-zsh as a read-only symlink into the nix store.
  # ZSH_COMPDUMP is overridden in zshrc to keep the completion cache writable.
  home.file.".oh-my-zsh".source = "${pkgs.oh-my-zsh}/share/oh-my-zsh";

  # OMZ custom plugins sourced from nixpkgs. ZSH_CUSTOM in zshrc points
  # at ~/.oh-my-zsh-custom and OMZ loads each plugin from plugins/<name>/.
  home.file.".oh-my-zsh-custom/plugins/fast-syntax-highlighting".source =
    "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting";
  home.file.".oh-my-zsh-custom/plugins/zsh-autosuggestions".source =
    "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions";
  home.file.".oh-my-zsh-custom/plugins/zsh-fzf-history-search".source =
    "${pkgs.zsh-fzf-history-search}/share/zsh-fzf-history-search";

  # Powerlevel10k as an OMZ custom theme. ZSH_THEME="powerlevel10k/powerlevel10k"
  # resolves to $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme.
  home.file.".oh-my-zsh-custom/themes/powerlevel10k".source =
    "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
  home.file.".p10k.zsh".source = ../../config/shell/p10k.zsh;

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
    zsh-powerlevel10k
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
    bun
    atomicparsley
    vips
    procps  # provides `watch`
    tree
    (pkgs.callPackage ../notunes.nix { })
    (pkgs.callPackage ../alttab.nix { })
    (pkgs.callPackage ../ccusage.nix { })
    (pkgs.callPackage ../claude-code.nix { })
    (pkgs.callPackage ../codex.nix { })
    (pkgs.callPackage ../pi.nix { })
    diffnav
  ] ++ lib.optionals stdenv.isDarwin [
    coreutils
  ] ++ lib.optionals stdenv.isLinux [
  ];
}
