brew_install() {
  echo "\n⚙️⚙️ Installing $1"
  if brew list $1 &>/dev/null; then
    echo "✅ ${1} is already installed"
  else
    brew install $2 $1 && echo "✅ $1 is installed"
  fi
}

packages=(
  git-open
  direnv
  zsh-autosuggestions
  git
  lazygit
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
  vlc
  bitwarden
  rectangle
  stats
  cloudflare-warp
  obsidian
  notion
  shottr
)

for cask in "${casks[@]}"; do
  brew_install "$cask" "--cask"
done
