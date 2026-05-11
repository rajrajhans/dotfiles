todo: readme

## steps

1. install Nix (Determinate installer):
   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
2. build and switch the darwin system (installs Homebrew + casks/brews declaratively via `nix-homebrew`):
   ```sh
   nix build .#darwinConfigurations.mbp.system
   ./result/sw/bin/darwin-rebuild switch --flake .
   ```
3. build and activate the home-manager flake:
   ```sh
   ./setup_nix.sh
   ```
4. symlink any remaining traditional dotfiles:
   ```sh
   ./setup_dotfiles.sh
   ```
