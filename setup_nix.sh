#!/bin/bash

function nix-profile() {
    # later when we have more profiles, which profile to choose can be selected here. right now, there's just one.
    local profile="mbp"
    echo $profile
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
