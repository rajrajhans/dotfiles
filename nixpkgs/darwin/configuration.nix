{ ... }:

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
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

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
