#!/usr/bin/env bash

set -e
shopt -s extglob

# Cleaning the TTY
clear


# ------------------------------------------------------------------------------
# Variable Definitions - User Defined
# ------------------------------------------------------------------------------

rest=1                         # Scripting variable to control pause delay (set to 0 for no pauses; set to 1 for comfortable pauses)
aurhelper="aura"               # AUR helper
sway="1"                       # Indicator that sway packages should be installed 
xfce="1"                       # Indicator that xfce packages should be installed

# Sway package group (imports from sway_pkg file)
mapfile -t sway_pkgs < sway_pkg

# XFCE package group (imports from xfce_pkg file)
mapfile -t xfce_pkgs < xfce_pkg

# Extras package group (imports from extras_pkg file)
mapfile -t extras_pkgs < extras_pkg

# AUR package group (imports from aur_pkg file)
mapfile -t aur_pkgs < aur_pkg

# ------------------------------------------------------------------------------
# Pretty Print Functions
# ------------------------------------------------------------------------------

# Cosmetics (colours for text in the pretty print functions)
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print for general information
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for user input
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Pretty print to alert user of bad input
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}


# ------------------------------------------------------------------------------
# Sleep Time Function
# -----------------------------------------------------------------------------y-

# Sets sleep time to allow for pauses (or no pauses) during the script to let the user follow along
sleepy() {
    let "t = $1 * $rest"
    sleep $t
}


# ------------------------------------------------------------------------------
# Internet Connection Functions
# ------------------------------------------------------------------------------

# Exit the script if there is no internet connection
not_connected() {
    sleepy 2
    
    error_print "No network connection!!!  Exiting now."
    sleepy 1
    error_print "Your entire life has been a mathematical error."
    exit 1
}

# Check for working internet connection
check_connection() {
    clear
    
    info_print "Trying to ping archlinux.org . . . ."
    $(ping -c 3 archlinux.org &>/dev/null) ||  not_connected
    
    info_print "Connection good!"
    sleepy 1
    info_print "Well done, android." && sleepy 3
}


# ------------------------------------------------------------------------------
# AUR Helper Installation Function
# ------------------------------------------------------------------------------

# Installs the preferred AUR Helper
install_aurhelper() {
    clear

    if [ -n "$aurhelper" ] ; then
        info_print "Installing AUR helper ($aurhelper) . . . ."
        mkdir ~/tmp
        cd ~/tmp
        sudo git clone "https://aur.archlinux.org/$aurhelper-bin.git"
        cd "$aurhelper-bin"
        sudo makepkg --noconfirm -si
        cd ..
        rm -rf "$aurhelper-bin"     
    fi    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Sway Packages Installation Function
# ------------------------------------------------------------------------------

# Installs the necessary sway packages
install_sway() {
    clear
    
    info_print "Installing sway packages . . . ."
    sudo pacman -S --needed --noconfirm "${sway_pkgs[@]}"
    sleepy 3
}


# ------------------------------------------------------------------------------
# XFCE Packages Installation Function
# ------------------------------------------------------------------------------

# Installs the necessary XFCE packages
install_xfce() {
    clear
    
    info_print "Installing XFCE packages . . . ."
    sudo pacman -S --needed --noconfirm "${xfce_pkgs[@]}"
    sleepy 3
}


# ------------------------------------------------------------------------------
# Extras Packages Installation Function
# ------------------------------------------------------------------------------

# Installs the user Extras packages
install_extras() {
    clear
    
    info_print "Installing Extras packages . . . ."
    sudo pacman -S --needed --noconfirm "${extras_pkgs[@]}"
    sleepy 3
}


# ------------------------------------------------------------------------------
# AUR Packages Installation Function
# ------------------------------------------------------------------------------

# Installs the necessary AUR packages
install_aur() {
    clear
    
    info_print "Installing AUR packages . . . ."
    sudo aura -A "${aur_pkgs[@]}"
    sleepy 3
}


# ------------------------------------------------------------------------------
# Enable Services Function
# ------------------------------------------------------------------------------i

# Enables additional systemd services
enable_services() {
    clear
    
    info_print "Enabling pipewire services . . . ."
    sudo systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber
    sleepy 2

    info_print "Enabling log-in manager service . . . ."
    sudo systemctl enable ly
    sleepy 3
}


# ------------------------------------------------------------------------------
# Begin Install
# ------------------------------------------------------------------------------

clear

# Welcome message
info_print "Hello? Friend."
sleepy 1
info_print "Arch Linux installation will now be completed . . . ."
sleepy 3

# Check for working internet connection; will exit script if there is no connection
check_connection

# Install AUR Helper
if [ -n "$aurhelper" ] ; then
    install_aurhelper
fi

# Install Sway packages
if [ -n "$sway" ] ; then
    install_sway
fi

# Install XFCE packages
if [ -n "$xfce" ] ; then
    install_xfce
fi

# Install Extras packages
install_extras

# Enable Services
enable_services

# Clean up
sudo rm -f /etc/sudoers.d/wheelnopasswd
info_print "Installation complete. Rebooting now . . . ."
sudo reboot now
