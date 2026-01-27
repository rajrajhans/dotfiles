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

    # Check if home-manager is installed
    if ! command -v home-manager &> /dev/null; then
        echo "Installing home-manager..."
        nix-env -iA nixpkgs.home-manager
    fi
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
    home-manager switch --flake ".#$profile" $(impure-flag)
}

function nix-update() {
    nix flake update --extra-experimental-features 'nix-command flakes'
}

# Main execution
echo "Starting Nix setup for $(nix-profile) profile..."

setup-prerequisites
nix-build
nix-activate
nix-switch

echo "Setup complete!"