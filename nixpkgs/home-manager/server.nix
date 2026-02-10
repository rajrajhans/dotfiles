{ config, pkgs, ... }:

let
  envUser = builtins.getEnv "USER";
  envHome = builtins.getEnv "HOME";
  username = if envUser != "" then envUser else "user";
  homeDirectory = if envHome != "" then envHome else "/home/user";
in
{
  imports = [
    ./modules/home-manager.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
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
    lazygit
    gh

    # File operations
    rsync
    yazi

    # System utilities
    direnv
    age
    duf
    neofetch
    just

    # Documentation
    tealdeer

    # Development tools
    python3
    nodejs
    (pkgs.callPackage ../claude-code.nix { })

    # Media utilities
    yt-dlp
    ffmpeg
  ];

  home.file.".local/bin/claude".source = "${pkgs.callPackage ../claude-code.nix { }}/bin/claude";

  xdg.configFile."yazi/theme.toml".source = ../../config/yazi/theme.toml;

  # Enable direnv for project-specific environments
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Git configuration
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Nord";
      true-color = "always";
      file-style = "#84a0c6";
      hunk-header-style = "#84a0c6";
      plus-style = "syntax #45493e";
      plus-emph-style = "syntax #2C3025";
      minus-style = "normal #53343b";
      minus-emph-style = "normal #200108";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Raj Rajhans";
      user.email = "me@rajrajhans.com";
      core.editor = "vim";
      pull.rebase = false;
      rebase.autoStash = true;
      init.defaultBranch = "main";
    };
    ignores = [
      ".DS_Store"
      "Desktop.ini"
      ".Trashes"
      "node_modules"
      "npm-debug.log"
      "yarn-debug.log"
      ".idea"
    ];
  };

  # Bash configuration
  programs.bash = {
    enable = true;
    historySize = 10000;
    historyFileSize = 10000;
    historyControl = [ "ignoreboth" ];
    shellOptions = [
      "histappend"
      "checkwinsize"
      "autocd"
    ];
    shellAliases = {
      # git
      g = "git";
      lg = "lazygit";
      gaa = "git add --all";
      gc = "git commit -m";
      gcl = "git clone";
      gs = "git status";
      gsv = "git status -v";
      gm = "git merge";
      gd = "git diff";
      gco = "git checkout";
      gcob = "git checkout -b";
      g-current-branch = "git rev-parse --abbrev-ref HEAD";
      gpo = "git push origin";
      gpoc = "git push origin $(git rev-parse --abbrev-ref HEAD)";
      gplo = "git pull origin";
      gploc = "git pull origin $(git rev-parse --abbrev-ref HEAD)";
      gstsh = "git stash";
      gpop = "git stash pop";
      gdeepclean = "git clean -fdx";
      ghpr = "gh pr view --web";
      gresh = "git reset --hard";
      gupdate = "git checkout main && git pull origin main && git checkout - && git merge main";
      gsubupdate = "git submodule update --init --recursive";
      # general
      cls = "clear";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      ls = "ls -a --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -alF";
      realtimeutc = ''while true; do printf "%s\r" "$(date -u)"; done'';
      checkip = "curl ipinfo.io/ip";
      # kubectl
      kc = "kubectl";
      kcg = "kubectl get";
      kcga = "kubectl get --all-namespaces";
      kcapply = "kubectl apply -f";
      ccc = "claude --dangerously-skip-permissions";
    };
    initExtra = ''
      # yazi wrapper: cd into browsed directory on quit
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
      }

      # colored prompt
      PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\] '

      # gundo function
      gundo() {
        git reset HEAD~$1
      }

      # source system bash completion if available
      [ -f /etc/profile.d/bash_completion.sh ] && source /etc/profile.d/bash_completion.sh

      eval "$(zoxide init bash)"
    '';
  };

  # tmux configuration
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    mouse = true;
  };

  # inputrc
  home.file.".inputrc".text = ''
    # Respect default shortcuts.
    $include /etc/inputrc

    ## arrow up
    "\e[A":history-search-backward
    ## arrow down
    "\e[B":history-search-forward
  '';
}
