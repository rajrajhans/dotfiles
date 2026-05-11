# New MacBook setup

Steps to bring up a fresh macOS machine from this dotfiles repo.

## 1. Install Determinate Nix

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

The `--determinate` flag installs Determinate Nix (their fork) rather than upstream Nix. The darwin config assumes Determinate is in use (`nix.enable = false` defers Nix management to it).

Open a new shell afterwards so `/nix/var/nix/profiles/default/bin` is on `PATH`.

## 2. Clone the repo

```sh
git clone https://github.com/rajrajhans/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

## 3. Run the setup script

```sh
./setup_nix.sh
```

This will:
1. Build and activate the home-manager profile (`mbp`).
2. Run `darwin-rebuild switch`, which on first run installs Homebrew via `nix-homebrew` and then every cask/brew listed in `nixpkgs/darwin/configuration.nix`.

Expect a sudo prompt and a long first run while casks download.

## Iterating from here

The strategy after first boot is to SSH in from the old laptop and migrate
settings/preferences incrementally — adding to the cask list, pulling over
app-specific config, etc. Each addition is a small PR-sized change:

1. Edit `nixpkgs/darwin/configuration.nix` (for brews/casks) or the
   home-manager modules (for user-level config).
2. `./setup_nix.sh` to re-apply.
3. Commit and push.

## Things not covered by Nix

These still need manual setup on the new machine:

- Raycast settings (export from old machine: Settings → Advanced → Export, then import).
- iTerm2: open Preferences → General → Preferences and tick "Load preferences from a custom folder", pointed at `~/.config/iterm2`. (The plist itself is already symlinked there by home-manager; this just tells iTerm2 to use it.)
- iCloud / Apple ID sign-in.
- Bitwarden login (unlocks everything else).
- Syncthing pairing (so `~/rdrive` syncs — this is where oh-my-zsh custom plugins live, see `shell/zshrc:3`).
- Browser sign-ins.
- SSH keys (decide: copy from old machine, or generate fresh and re-add to GitHub etc.).
