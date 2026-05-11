# CLAUDE.md

Guidance for Claude Code when working in this repo.

## Overview

Personal dotfiles repo. Three layers:

1. **System (macOS only)** — nix-darwin, managing `/etc`, launchd, system defaults, and Homebrew via `nix-homebrew`. Entry point: `nixpkgs/darwin/configuration.nix`.
2. **User (cross-platform)** — home-manager, managing `$HOME`, user packages, dotfiles, user launchd agents. Entry points: `nixpkgs/home-manager/mbp.nix` (macOS) and `nixpkgs/home-manager/server.nix` (Linux).
3. **Out-of-repo secrets** — anything matching `shell/private_*` is gitignored.

Nix is **Determinate Nix**; nix-darwin defers to it via `nix.enable = false`.

## Layout

- `flake.nix`, `flake.lock` — flake inputs and outputs (homeConfigurations + darwinConfigurations).
- `nixpkgs/darwin/configuration.nix` — system-level macOS config (keyboard, TouchID, homebrew block).
- `nixpkgs/home-manager/mbp.nix` — main macOS home-manager profile.
- `nixpkgs/home-manager/server.nix` — Linux home-manager profile.
- `nixpkgs/home-manager/modules/` — reusable modules (`micro.nix`, `wakapi.nix`, `yazi.nix`).
- `nixpkgs/*.nix` — custom package derivations (`ccusage.nix`, `claude-code.nix`, `codex.nix`, `notunes.nix`, `statusline.nix`, `wakapi.nix`).
- `nixpkgs/update-claude-code.sh` + `claude-code-hashes.json` — version pinning for `claude-code.nix`.
- `shell/`, `git/`, `config/`, `iterm2/` — dotfile sources, symlinked from home-manager via `home.file`.
- `scripts/` — user scripts symlinked into `~/.local/bin`.
- `docs/new-mbp.md` — fresh-laptop setup steps.

## Common commands

```bash
# Apply everything (home-manager + darwin-rebuild on macOS)
./setup_nix.sh

# Just home-manager
home-manager switch --flake .#mbp

# Just darwin
sudo darwin-rebuild switch --flake .#mbp

# Update flake inputs
nix flake update
```

`setup_nix.sh` picks the profile from `uname` (`mbp` on Darwin, `server` on Linux). Override via `NIX_PROFILE=foo`.

## Notes

- Caps Lock is remapped to Escape system-wide.
- TouchID is enabled for `sudo`.
- Both x86_64 and aarch64 Darwin are supported.
- Homebrew casks live in `nixpkgs/darwin/configuration.nix` and are installed declaratively via `nix-homebrew`.
