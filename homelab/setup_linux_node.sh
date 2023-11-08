#!/bin/bash

# assumes that needed envs are present in /boot/firmware/node.env file
source /boot/firmware/node.env

# connect to wifi
tee /etc/wpa_supplicant.conf >/dev/null <<EOL
network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
}
EOL

echo "Connecting to Wi-Fi network: $WIFI_SSID"
wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf

# configure to auto-connect to wifi on startup
touch /etc/rc.local
chmod +x /etc/rc.local
tee -a /etc/rc.local >/dev/null <<EOL
# Connect to Wi-Fi at startup
wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf
EOL

# create a systemd service to execute /etc/rc.local at startup
tee /etc/systemd/system/rc-local.service >/dev/null <<EOL
[Unit]
Description=/etc/rc.local Compatibility
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
systemctl enable rc-local
