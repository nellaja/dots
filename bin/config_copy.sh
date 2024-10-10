#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

clear

cd ~/.etc

# Zram Configuration
sudo cp zram-generator.conf /etc/systemd
sudo cp 99-vm-zram-parameters.conf /etc/sysctl.d

# Configure NetworkManager
sudo cp no-systemd-resolved.conf /etc/NetworkManager/conf.d

# Configure nsswitch
sudo cp nsswitch.conf /etc

# Harden pam settings
sudo cp su /etc/pam.d
sudo cp su-l /etc/pam.d
sudo cp system-login /etc/pam.d
