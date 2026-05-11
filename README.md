# dotfiles

Personal Nix-based dotfiles for macOS (and a Linux server profile).

## Architecture

Three layers, each managing a different scope:

| Layer | Tool | Scope | Entry point |
|---|---|---|---|
| System (macOS only) | nix-darwin | `/etc`, launchd, system defaults, Homebrew | `nixpkgs/darwin/configuration.nix` |
| User (cross-platform) | home-manager | `$HOME`, user packages, dotfiles, user launchd agents | `nixpkgs/home-manager/mbp.nix` (macOS), `server.nix` (Linux) |
| Secrets (out-of-repo) | manual / Syncthing | anything matching `config/shell/private_*` (gitignored) | n/a |

nix-darwin is macOS-only — on Linux servers the `server` profile uses home-manager standalone (no darwin layer).

## New machine setup

See [docs/new-mbp.md](docs/new-mbp.md).

## Common commands

```sh
# Apply everything (home-manager + darwin-rebuild on macOS)
./setup_nix.sh

# Update flake inputs
nix flake update

# Just the darwin system
sudo darwin-rebuild switch --flake .#mbp

# Just home-manager
home-manager switch --flake .#mbp
```

## Profile selection

`setup_nix.sh` picks the profile from `uname`:
- macOS → `mbp` (home-manager + darwin)
- Linux → `server` (home-manager only)

Override with `NIX_PROFILE=foo ./setup_nix.sh`.
