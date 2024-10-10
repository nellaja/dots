#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

clear

# Enable Zram
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0

# Enable System Services
sudo systemctl enable avahi-daemon bluetooth cups firewalld systemd-timesyncd fstrim.timer
systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber
