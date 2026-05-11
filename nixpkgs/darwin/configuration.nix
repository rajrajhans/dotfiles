{ pkgs, lib, ... }:

{
  # Nix configuration ------------------------------------------------------------------------------

  nix.binaryCaches = [
    "https://cache.nixos.org/"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
  nix.trustedUsers = [
    "@admin"
  ];
  
  users.nix.configureBuildUsers = true;

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # Homebrew (managed via nix-homebrew). GUI apps and a couple of CLIs that
  # aren't in nixpkgs or that we specifically want from brew.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # "none" leaves manually-installed brews alone. Switch to "uninstall"
      # or "zap" later if you want strict declarative management.
      cleanup = "none";
    };

    taps = [
      "cloudflare/cloudflare"
    ];

    brews = [
      "cloudflared"
    ];

    casks = [
      # browsers
      "google-chrome"
      "firefox"

      # dev tools
      "iterm2"
      "visual-studio-code"
      "sublime-text"
      "docker"
      "dbeaver-community"
      "insomnia"
      "pomerium-desktop"

      # utility tools
      "bitwarden"
      "rectangle"
      "stats"
      "cloudflare-warp"
      "obsidian"
      "notion"
      "shottr"
      "transmission"
      "itsycal"
      "raycast"

      "xbar"
    ];
  };
}
