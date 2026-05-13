{ config, ... }:

{
  # Nix is managed by Determinate Nix, not nix-darwin.
  # See: https://github.com/DeterminateSystems/nix-installer
  # Experimental features, the official cache, and trusted users are configured
  # by the Determinate installer; per-host overrides go in /etc/nix/nix.custom.conf.
  nix.enable = false;

  # Required for `homebrew` and other options that act on a specific user.
  system.primaryUser = "rajrajhans";

  # Set once on install; do not change without reading darwin-rebuild changelog.
  system.stateVersion = 6;

  # Keyboard
  system.keyboard.enableKeyMapping = false;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # System preferences — captured from System Settings.
  system.defaults = {
    dock = {
      autohide = true;
      tilesize = 76;
      wvous-br-corner = 1;  # bottom-right hot corner disabled
    };
    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";  # list view
      FXEnableExtensionChangeWarning = false;
    };
    menuExtraClock = {
      ShowSeconds = true;
      Show24Hour = false;
      ShowAMPM = false;
      ShowDate = 2;          # 0 auto, 1 always, 2 never
      ShowDayOfWeek = false;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;            # min UI slider; lower = faster repeats
      InitialKeyRepeat = 15;    # min UI slider; lower = shorter delay
      ApplePressAndHoldEnabled = false;  # so held keys repeat instead of showing accent picker
      "com.apple.keyboard.fnState" = true;  # F1–F12 act as standard function keys, not media keys
      AppleFnUsageType = 0;  # fn key does nothing (0=nothing, 1=input source, 2=emoji, 3=dictation)
    };
    # Disable all built-in screenshot shortcuts (using Shottr instead).
    # symbolichotkeys IDs: 28=save screen, 29=copy screen, 30=save area,
    # 31=copy area, 184=screenshot/recording options (⇧⌘5).
    CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      "28" = { enabled = false; };
      "29" = { enabled = false; };
      "30" = { enabled = false; };
      "31" = { enabled = false; };
      "184" = { enabled = false; };
    };
  };

  # Homebrew (managed via nix-homebrew). GUI apps and a couple of CLIs that
  # aren't in nixpkgs or that we specifically want from brew.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # "uninstall" removes brews/casks not in this file; preferences in
      # ~/Library/... are left intact (unlike "zap").
      cleanup = "uninstall";
    };

    casks = [
      # browsers
      "google-chrome"
      "firefox"

      # dev tools
      "iterm2"
      "cursor"
      "sublime-text"
      "docker"
      "dbeaver-community"

      # utility tools
      "bitwarden"
      "maccy"
      "rectangle"
      "stats"
      "cloudflare-warp"
      "tailscale-app"
      "obsidian"
      "notion"
      "shottr"
      "transmission"
      "itsycal"
      "monitorcontrol"
      "raycast"
    ];
  };

  # Copy home-manager-installed .app bundles into /Applications/Nix Apps so
  # Spotlight, Launchpad, and the Dock can find them. Nix store paths and the
  # ~/Applications/Home Manager Apps symlink chain are not indexed by Launch
  # Services, so plain symlinks do not show up in search.
  system.activationScripts.nixApps.text = ''
    nixAppsDir="/Applications/Nix Apps"
    hmAppsDir="/Users/${config.system.primaryUser}/Applications/Home Manager Apps"

    rm -rf "$nixAppsDir"
    mkdir -p "$nixAppsDir"

    if [ -d "$hmAppsDir" ]; then
      find "$hmAppsDir" -maxdepth 1 -name '*.app' | while read -r app; do
        target=$(readlink -f "$app")
        name=$(basename "$app")
        echo "copying $name to $nixAppsDir" >&2
        cp -R "$target" "$nixAppsDir/$name"
      done
    fi
  '';
}
