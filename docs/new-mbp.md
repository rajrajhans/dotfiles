# New MacBook setup

```sh
# 1. Install Determinate Nix
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate

# 2. Open a new shell, then:
git clone https://github.com/rajrajhans/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup_nix.sh
```

`setup_nix.sh` activates home-manager and runs `darwin-rebuild switch` (installs Homebrew + all casks on first run).
