#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

clear

# Enable Zram
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0

# Enable System Services and Timers
sudo systemctl enable avahi-daemon bluetooth cups firewalld smartd systemd-timesyncd 
sudo systemctl enable fstrim.timer paccache.timer pkgfile-update.timer
systemctl --user enable pipewire pipewire-pulse wireplumber
