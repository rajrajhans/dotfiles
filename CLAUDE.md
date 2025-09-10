# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using Nix/NixOS with Home Manager and nix-darwin for macOS system configuration. The repository manages both system-level configuration and user dotfiles through a flake-based setup.

## Architecture

### Nix Flake Structure
- `flake.nix` - Main flake configuration defining inputs and outputs
- `nixpkgs/home-manager/mbp.nix` - Main Home Manager configuration for MacBook Pro profile
- `nixpkgs/home-manager/modules/` - Modular configuration split:
  - `common.nix` - Package installations and common settings
  - `home-manager.nix` - Home Manager enablement
- `nixpkgs/darwin/configuration.nix` - nix-darwin system configuration (keyboard, security, nix daemon)

### Configuration Layers
1. **System Level** (nix-darwin): System keyboard mapping, TouchID sudo auth, nix daemon configuration
2. **User Level** (Home Manager): Package management, user applications, dotfiles
3. **Traditional Dotfiles**: Shell configurations, git config, application settings

## Common Commands

### Nix Management
```bash
# Build the Home Manager configuration
nix build --no-link .#homeConfigurations.mbp.activationPackage

# Activate configuration (from setup_nix.sh functions)
"$(nix path-info .#homeConfigurations.mbp.activationPackage)"/activate

# Switch to new configuration 
home-manager switch --flake ".#mbp"

# Update flake inputs
nix flake update

# Build Darwin system configuration
nix build .#darwinConfigurations.mbp.system

# Apply Darwin configuration
./result/sw/bin/darwin-rebuild switch --flake .
```

### Setup Scripts
```bash
# Initial system setup (installs Homebrew, common software, Nix)
./macos/setup_common_software.sh

# Symlink dotfiles to home directory
./setup_dotfiles.sh

# Build and activate Nix configuration
./setup_nix.sh
```

### Profile Management
The configuration uses a "mbp" profile by default. Functions in `setup_nix.sh` automatically reference this profile.

## Key Dotfiles Managed
- Shell: `shell/zshrc`, `shell/wakatime.cfg`
- Git: `git/gitconfig`, `git/gitignore` 
- Config: `config/iex.exs` (Elixir IEx configuration)

## Package Management Strategy
- **Nix packages**: Core development tools, CLI utilities (defined in `common.nix`)
- **Homebrew**: GUI applications, some CLI tools not available in Nix
- **Custom packages**: `ccusage.nix` - custom package definition

## System Configuration Notes
- Caps Lock remapped to Escape at system level
- TouchID enabled for sudo authentication
- Nix configured with flakes and nix-command experimental features
- Both x86_64 and aarch64 Darwin platforms supported