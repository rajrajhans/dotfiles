#!/bin/bash

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

function nix-build() {
    local profile=$(nix-profile)
    nix build --no-link .#homeConfigurations.$profile.activationPackage
}

function nix-activate() {
    local profile=$(nix-profile)
    "$(nix path-info .#homeConfigurations.$profile.activationPackage)"/activate
}

function nix-switch() {
    local profile=$(nix-profile)
    home-manager switch --flake ".#$profile"
}

function nix-update() {
    nix flake update
}

nix-build
nix-activate
nix-switch
