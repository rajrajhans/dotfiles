# CLAUDE.md

Personal dotfiles. Two Nix layers:

- **System (macOS)**: nix-darwin → `nixpkgs/darwin/configuration.nix`. Homebrew casks live here, installed via `nix-homebrew`.
- **User**: home-manager → `nixpkgs/home-manager/mbp.nix` (macOS), `server.nix` (Linux).

Nix is **Determinate Nix**; nix-darwin defers to it (`nix.enable = false`).

Apply everything: `./setup_nix.sh` (picks profile from `uname`).

Secrets matching `config/shell/private_*` are gitignored — not in Nix.
