{ config, pkgs, pkgsUnstable, lib, ... }:

let
  # Tailnet sidecar: a second userspace tailscaled joined to the personal tailnet,
  # exposing a SOCKS5/HTTP proxy on 127.0.0.1:1055 while the host Tailscale app stays
  # on the work tailnet. See ../../tailnet-sidecar/GOALS.md.
  tailnetSidecarDir = "${config.home.homeDirectory}/.local/state/tailnet-sidecar";
  tailnetSidecarSocket = "${tailnetSidecarDir}/tailscaled.sock";
  tailnetSidecarProxy = "127.0.0.1:1055";

  # The PAC is served over http (not file://) so Chrome will load it — Chrome refuses
  # file:// PAC URLs. A dedicated caddy launchd agent serves the single source-of-truth
  # PAC (tailnet-sidecar/tailnet-sidecar.pac) from its own directory (kept separate from
  # the tailscaled state dir so caddy never exposes the daemon state/socket).
  tailnetSidecarPacDir = "${config.home.homeDirectory}/.local/state/tailnet-sidecar-pac";
  tailnetSidecarPacPort = "1056";
  tailnetSidecarPacUrl = "http://127.0.0.1:${tailnetSidecarPacPort}/tailnet-sidecar.pac";
in
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
  # CLI wrapper that targets the tailnet sidecar's tailscaled socket, e.g.
  #   tsidecar up --hostname=mac-tailnet-sidecar ; tsidecar status
  home.file.".local/bin/tsidecar" = { source = ../../scripts/tsidecar; executable = true; };

  # PAC served over http by the caddy agent below. Single source of truth; kept in its
  # own directory so caddy's file server only ever exposes this one file.
  home.file.".local/state/tailnet-sidecar-pac/tailnet-sidecar.pac".source =
    ../../tailnet-sidecar/tailnet-sidecar.pac;
  home.file.".config/tailnet-sidecar/pac.Caddyfile".text = ''
    {
    	admin off
    	auto_https off
    }
    http://127.0.0.1:${tailnetSidecarPacPort} {
    	bind 127.0.0.1
    	root * ${tailnetSidecarPacDir}
    	file_server
    	header Content-Type application/x-ns-proxy-autoconfig
    }
  '';
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

  # atuin config — shell history database & search (replaces the old
  # zsh-fzf-history-search and per-directory-history OMZ plugins).
  home.file.".config/atuin/config.toml".source = ../../config/atuin/config.toml;

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

  # Ensure the sidecar state/log directory exists before launchd starts tailscaled
  # (launchd will not create StandardOutPath's parent directory itself).
  home.activation.tailnetSidecarDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /bin/mkdir -p "${tailnetSidecarDir}/state"
  '';

  # Firefox uses the cask install with auto-named profiles, so its proxy PAC can't be
  # managed via programs.firefox/home.file. Write user.js into every existing profile
  # so Firefox routes *.internal through the tailnet sidecar (see config/firefox/user.js).
  home.activation.firefoxProxyUserJs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ffProfiles="$HOME/Library/Application Support/Firefox/Profiles"
    if [ -d "$ffProfiles" ]; then
      for prof in "$ffProfiles"/*/; do
        [ -d "$prof" ] || continue
        run /usr/bin/install -m 644 ${../../config/firefox/user.js} "''${prof}user.js"
      done
    fi
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

  launchd.agents.alttab = {
    enable = true;
    config = {
      Label = "com.lwouis.alt-tab-macos";
      ProgramArguments = [ "${pkgs.callPackage ../alttab.nix { }}/Applications/AltTab.app/Contents/MacOS/AltTab" ];
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
      # Route Syncthing's outbound connections through the tailnet sidecar so it reaches
      # the personal-tailnet hub (winterfell) while the host is on the work tailnet.
      # Process-global; safe because every Syncthing peer is on the personal tailnet.
      # See ../../tailnet-sidecar/GOALS.md.
      EnvironmentVariables = {
        ALL_PROXY = "socks5://${tailnetSidecarProxy}";
      };
    };
  };

  # Second tailscaled (userspace + SOCKS) for the personal tailnet. Coexists with the
  # official Tailscale.app via its own --socket/--statedir. Authenticate once, out of
  # band (key intentionally kept out of the nix store):
  #   tsidecar up --hostname=mac-tailnet-sidecar
  launchd.agents.tailnetSidecar = {
    enable = true;
    config = {
      Label = "com.rajrajhans.tailnet-sidecar";
      ProgramArguments = [
        "${pkgs.tailscale}/bin/tailscaled"
        "--tun=userspace-networking"
        "--socks5-server=${tailnetSidecarProxy}"
        "--outbound-http-proxy-listen=${tailnetSidecarProxy}"
        "--socket=${tailnetSidecarSocket}"
        "--statedir=${tailnetSidecarDir}/state"
        "--port=0"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${tailnetSidecarDir}/tailscaled.log";
      StandardErrorPath = "${tailnetSidecarDir}/tailscaled.log";
    };
  };

  # Serve the tailnet-sidecar PAC over http://127.0.0.1:1056 so Chrome/Safari (which
  # ignore file:// PACs) and the macOS system auto-proxy can fetch it.
  launchd.agents.tailnetSidecarPac = {
    enable = true;
    config = {
      Label = "com.rajrajhans.tailnet-sidecar-pac";
      ProgramArguments = [
        "${pkgs.caddy}/bin/caddy"
        "run"
        "--config"
        "${config.home.homeDirectory}/.config/tailnet-sidecar/pac.Caddyfile"
        "--adapter"
        "caddyfile"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${tailnetSidecarDir}/caddy-pac.log";
      StandardErrorPath = "${tailnetSidecarDir}/caddy-pac.log";
    };
  };

  home.packages = with pkgs; [
    fd
    ripgrep
    zsh
    zsh-powerlevel10k
    atuin
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
    tailscale  # CLI + tailscaled for the tailnet sidecar (see launchd.agents.tailnetSidecar)

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
    poppler-utils
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
