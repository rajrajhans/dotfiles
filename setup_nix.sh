#!/bin/bash

# Auto-setup script that handles everything
set -e

function nix-profile() {
    # Auto-detect profile based on system, or allow override with NIX_PROFILE env var
    if [ -n "$NIX_PROFILE" ]; then
        echo "$NIX_PROFILE"
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
    # Server profile needs --impure to read $USER/$HOME env vars
    if [[ "$profile" == "server" ]]; then
        echo "--impure"
    fi
}

function nix-build() {
    local profile=$(nix-profile)
    echo "Building configuration for profile: $profile"
    nix build --no-link .#homeConfigurations.$profile.activationPackage --extra-experimental-features 'nix-command flakes' $(impure-flag)
}

function nix-activate() {
    local profile=$(nix-profile)
    echo "Activating configuration..."
    "$(nix path-info .#homeConfigurations.$profile.activationPackage --extra-experimental-features 'nix-command flakes' $(impure-flag))"/activate
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

function nix-update() {
    nix flake update --extra-experimental-features 'nix-command flakes'
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
echo "Starting Nix setup for $(nix-profile) profile..."

setup-prerequisites
nix-build
nix-activate
nix-switch
darwin-switch

echo "Setup complete!"