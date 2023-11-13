#!/bin/bash

# assumes that needed envs are present in /boot/firmware/node.env file
source /boot/firmware/node.env

## connect to wifi
echo "⏳⏳ Connecting to Wi-Fi network: $WIFI_SSID"
wpa_passphrase $WIFI_SSID $WIFI_PWD >/etc/wpa_supplicant.conf
wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf -B

echo "⏳⏳ Waiting for Wi-Fi connection to be established"
dhclient wlan0 -v

# configure to auto-connect to wifi on startup
echo "⏳⏳ Configuring to auto-connect to Wi-Fi network: $WIFI_SSID"
touch /etc/rc.local
chmod +x /etc/rc.local
tee -a /etc/rc.local >/dev/null <<EOL
# Connect to Wi-Fi at startup
wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf
EOL
# create a systemd service to execute /etc/rc.local at startup
echo "⏳⏳ Creating systemd service to execute /etc/rc.local at startup"
tee /etc/systemd/system/rc-local.service >/dev/null <<EOL
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOL
# enable the rc-local service
echo "⏳⏳ Enabling the rc-local service"
systemctl enable rc-local

## update apt-get and install packages
echo "⏳⏳ Updating apt-get"
apt-get update
echo "⏳⏳ Installing packages"
apt-get install -y \
    apt-transport-https \
    bat \
    direnv \
    git \
    net-tools \
    zsh

## zsh setup
# set zsh as default shell
chsh -s $(which zsh)
# install oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# install zsh fast-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
# install zsh autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

## dotfiles setup
git clone $DOTFILES_GIT_REPO
# symlink dotfiles
echo "⏳⏳ Setting up dotfiles"
cd dotfiles
/bin/bash setup_dotfiles.sh

echo "🟢 All done!"
