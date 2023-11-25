#!/bin/bash

# validate sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root"
    exit
fi

# assumes that needed envs are present in /boot/firmware/node.env file
echo "⏳⏳ Loading environment variables"
source /boot/firmware/node.env

# validate envs
env_vars=("WIFI_SSID" "WIFI_PWD" "DOTFILES_GIT_REPO" "TAILSCALE_AUTH_KEY" "KUBERNETES_NODE_ROLE" "KUBERNETES_MASTER_URL" "KUBERNETES_CLUSTER_TOKEN")

for var in "${env_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Environment variable $var is not set"
        exit 1
    fi
done

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
#!/bin/sh
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
echo "🟢 Done with Wi-Fi setup"

## update apt-get and install packages
echo "⏳⏳ Updating apt-get"
apt-get update
echo "⏳⏳ Installing packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    bat \
    direnv \
    git \
    net-tools \
    linux-modules-extra-raspi
echo "🟢 Done with package installation"

## zsh setup
# set zsh as default shell
#chsh -s $(which zsh)
# install oh my zsh
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# install zsh fast-syntax-highlighting
#git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
# install zsh autosuggestions
#git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
echo "🟢 Done with zsh setup"

## dotfiles setup
git clone $DOTFILES_GIT_REPO
# symlink dotfiles
echo "⏳⏳ Setting up dotfiles"
cd dotfiles
/bin/bash setup_dotfiles.sh
echo "🟢 Done with dotfiles setup"

## tailscale setup
echo "⏳⏳ Installing tailscale"
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
apt-get update
apt-get install -y tailscale
echo "⏳⏳ Configuring tailscale"
tailscale up --authkey $TAILSCALE_AUTH_KEY
echo "🟢 Done with tailscale setup"

# kubernetes setup
echo "⏳⏳ Configuring Kubernetes"
# enable the control group subsystems for k8s to manage CPU and memory resources
# enable memory control group support, used by k8s to enforce memory limits and reservations
# enable tracking of swap usage in the memory resource controller, allows k8s to track and limit swap usage by pods
sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' /boot/firmware/cmdline.txt

if [ "$KUBERNETES_NODE_ROLE" == "master" ]; then
    # Install k3s
    curl -sfL https://get.k3s.io | sh -

    # set GOGC to 10
    echo "Environment=GOGC=10" >>/etc/systemd/system/k3s.service

    # disable cloud-controller in k3s systemd service
    sed -i 's/ExecStart=\/usr\/local\/bin\/k3s server/ExecStart=\/usr\/local\/bin\/k3s server --disable-cloud-controller/' /etc/systemd/system/k3s.service

    # set kubeconfig for kubectl
    export KUBECONFIG=~/.kube/config
    mkdir ~/.kube 2>/dev/null
    k3s kubectl config view --raw >"$KUBECONFIG"

    # Reload systemd to apply changes and restart service
    systemctl daemon-reload
    systemctl restart k3s

elif [ "$KUBERNETES_NODE_ROLE" == "worker" ]; then
    # Install k3s as a worker node
    curl -sfL http://get.k3s.io | K3S_URL=$KUBERNETES_MASTER_URL K3S_TOKEN=$KUBERNETES_CLUSTER_TOKEN sh -
fi

echo "🟢🟢 All done! Rebooting"

reboot
