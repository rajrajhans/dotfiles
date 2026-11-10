#!/bin/bash

# Auto-setup script that handles everything
set -e

MODE="default"

function usage() {
    cat <<'EOF_USAGE'
Usage: ./setup_nix.sh [--light | --upgrade]

Applies the dotfiles config exactly as pinned in flake.lock. Never bumps flake
inputs; do that yourself with `nix flake update <input>`.

  (no flag)   home-manager switch, then (macOS) darwin-rebuild switch. Installs
              casks newly added to the config, but does NOT upgrade or restart
              apps that are already installed.
  --light     home-manager switch only. Skips sudo, macOS system settings,
              Homebrew, launchd and proxy setup. Fast; use it when you only
              touched dotfiles, shell config or user packages.
  --upgrade   Everything in the default run, then `brew update && brew upgrade`
              (macOS). Upgrading casks can quit and restart running apps.
  -h, --help  Show this help.

Profile, first match wins:
  1. NIX_PROFILE=<name> in the environment.
  2. The name in ~/.config/dotfiles/nix-profile. A config that must not be
     replaced by the OS default writes its own name there when it is applied
     (box does), so later runs on that machine keep using it.
  3. mbp on macOS, server on Linux.
EOF_USAGE
}

function parse-args() {
    for arg in "$@"; do
        case "$arg" in
            --light|--upgrade)
                if [[ "$MODE" != "default" && "$MODE" != "${arg#--}" ]]; then
                    echo "error: --light and --upgrade are mutually exclusive" >&2
                    exit 2
                fi
                MODE="${arg#--}"
                ;;
            -h|--help) usage; exit 0 ;;
            *) echo "error: unknown option: $arg" >&2; usage >&2; exit 2 ;;
        esac
    done
}

PROFILE_PIN="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/nix-profile"

function nix-profile() {
    # NIX_PROFILE, then the machine's pinned profile, then the OS default.
    local pinned=""
    if [ -r "$PROFILE_PIN" ]; then
        pinned="$(head -n 1 "$PROFILE_PIN" | tr -cd 'A-Za-z0-9_-')"
    fi
    if [ -n "$NIX_PROFILE" ]; then
        echo "$NIX_PROFILE"
    elif [ -n "$pinned" ]; then
        echo "$pinned"
    else
        case "$(uname)" in
            "Darwin") echo "mbp" ;;
            "Linux") echo "server" ;;
            *) echo "mbp" ;;  # default fallback
        esac
    fi
}

function setup-prerequisites() {
    echo "Setting up prerequisites..."

    # Enable experimental features
    export NIX_CONFIG="experimental-features = nix-command flakes"
}

function impure-flag() {
    local profile=$(nix-profile)
    # The Linux profiles need --impure to read $USER/$HOME env vars
    if [[ "$profile" != "mbp" ]]; then
        echo "--impure"
    fi
}

function nix-switch() {
    local profile=$(nix-profile)
    echo "Switching to configuration..."
    if command -v home-manager &>/dev/null; then
        home-manager switch --flake ".#$profile" -b backup $(impure-flag)
    else
        # First-time bootstrap: home-manager isn't on PATH yet. Run it
        # ephemerally via `nix run`; the switch itself installs home-manager
        # into the profile for subsequent invocations.
        nix run nixpkgs#home-manager --extra-experimental-features 'nix-command flakes' -- \
            switch --flake ".#$profile" -b backup $(impure-flag)
    fi
}

function brew-upgrade() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 0
    fi
    local brew=/opt/homebrew/bin/brew
    echo "Updating Homebrew and upgrading installed apps..."
    "$brew" update
    echo "Outdated:"
    "$brew" outdated --verbose || true
    "$brew" upgrade
}

function darwin-switch() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 0
    fi
    local profile=$(nix-profile)
    echo "Switching darwin system configuration for profile: $profile..."
    if command -v darwin-rebuild &>/dev/null; then
        sudo darwin-rebuild switch --flake ".#$profile"
    else
        # First-time bootstrap: darwin-rebuild isn't on PATH yet.
        nix build ".#darwinConfigurations.$profile.system" --extra-experimental-features 'nix-command flakes'
        sudo ./result/sw/bin/darwin-rebuild switch --flake ".#$profile"
    fi
}

# Main execution
parse-args "$@"
echo "Starting Nix setup for $(nix-profile) profile ($MODE mode)..."

setup-prerequisites
nix-switch
if [[ "$MODE" != "light" ]]; then
    darwin-switch
fi
if [[ "$MODE" == "upgrade" ]]; then
    brew-upgrade
fi

echo "Setup complete!"