brew_install() {
  echo "\n⚙️⚙️ Installing $1"
  if brew list $1 &>/dev/null; then
    echo "✅ ${1} is already installed"
  else
    brew install $2 $1 && echo "✅ $1 is installed"
  fi
}

packages=(
  cloudflare/cloudflare/cloudflared
  pomerium-desktop
)

for package in "${packages[@]}"; do
  brew_install "$package"
done

casks=(
  # browsers
  google-chrome
  firefox

  # dev tools
  iterm2
  visual-studio-code
  sublime-text
  docker
  dbeaver-community
  insomnia

  # utility tools
  bitwarden
  rectangle
  stats
  cloudflare-warp
  obsidian
  notion
  shottr
  transmission
  itsycal

  xbar
)

for cask in "${casks[@]}"; do
  brew_install "$cask" "--cask"
done

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" ]; then
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if ! command -v nix &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi
