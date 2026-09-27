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

## Skill listing

`skills` (or `sk`) shows a compact, colored inventory of the current directory's
`.claude/skills`, `.agents/skills`, and legacy `.codex/skills` folders. It reads
`SKILL.md` names and descriptions, including nested and symlinked skill folders.
It lists local files, not the agent's effective session skills: parent directories,
global skills, and installed plugins are excluded.

```sh
skills                  # current directory
sk ~/projects/my-app    # another directory
sk --long               # full descriptions and source paths
```

Colors are disabled when piped or when `NO_COLOR` is set. Both home-manager
profiles install the command and alias; apply with `home-manager switch --flake .#mbp`
(or `.#server` on Linux), then open a new shell.

## Profile selection

`setup_nix.sh` picks the profile from `uname`:
- macOS → `mbp` (home-manager + darwin)
- Linux → `server` (home-manager only)

Override with `NIX_PROFILE=foo ./setup_nix.sh`.
