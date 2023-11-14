#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

# Cleaning the TTY
clear


# ------------------------------------------------------------------------------
# Variable Definitions - User Defined
# ------------------------------------------------------------------------------

rest=1                         # Scripting variable to control pause delay (set to 0 for no pauses; set to 1 for comfortable pauses)
keymap="us"                    # Console keymap setting (localectl list-keymaps)
font="ter-120b"                # Console font (ls -a /usr/share/kbd/consolefonts)
device="/dev/XXXX"             # Device name for the install location (e.g., /dev/nvme0n1, /dev/sda)
kernel="lts"                   # Additional kernel to install (do not include linux prefix) 
timezone="America/New_York"    # Location timezone
locale="en_US.UTF-8"           # Locale and language variable 
hostname=""                    # Machine hostname
username=""                    # Main user
gpu=""                         # GPU manufacturer (amd or intel)[lspci | grep VGA]    

# Base system package group
base_system=(base base-devel linux linux-firmware vim terminus-font git networkmanager efibootmgr zram-generator)

# Essential system package group (imports from essentials_pkg file)
curl -O -s https://raw.githubusercontent.com/nellaja/dots/main/bin/essentials_pkg
mapfile -t essentials < essentials_pkg

# System font packages (imports from fonts_pkg file)
curl -O -s https://raw.githubusercontent.com/nellaja/dots/main/bin/fonts_pkg
mapfile -t fonts < fonts_pkg

# ------------------------------------------------------------------------------
# Variable Definitions - Auto Defined
# ------------------------------------------------------------------------------

# Define the partition numbers for boot and root partitions based on the provided device name
if [ "${device::8}" == "/dev/nvm" ] ; then
    bootdev="${device}p1"
    rootdev="${device}p2"
else
    bootdev="${device}1"
    rootdev="${device}2"
fi

# Determine the CPU manufacturer and assign corresponding microcode values
cpu=$(lscpu | grep "Vendor ID:")

if [[ "$cpu" == *"AuthenticAMD"* ]] ; then
    cpu="AMD"
    microcode="amd-ucode"
    microcode_img="amd-ucode.img"
else
    cpu="Intel"
    microcode="intel-ucode"
    microcode_img="intel-ucode.img"
fi


# ------------------------------------------------------------------------------
# Variable Definitions - Universal
# ------------------------------------------------------------------------------

# Array of modules to check if they exist on the system to determine if alsa-firmware package is required
alsa_array=(snd_asihpi snd_cs46xx snd_darla20 snd_darla24 snd_echo3g snd_emu10k1 snd_gina20 snd_gina24 snd_hda_codec_ca0132 snd_hdsp snd_indigo snd_indigodj snd_indigodjx snd_indigoio snd_indigoiox snd_layla20 snd_layla24 snd_mia snd_mixart snd_mona snd_pcxhr snd_vx_lib)


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
    sleepy 2
    error_print "This is your fault. It didn't have to be like this."
    exit 1
}

# Check for working internet connection
check_connection() {
    clear
    
    info_print "Trying to ping archlinux.org . . . ."
    $(ping -c 3 archlinux.org &>/dev/null) ||  not_connected
    
    info_print "Connection good!"
    sleepy 2
    info_print "Thank you for helping us help you help us all." && sleepy 3
}


# ------------------------------------------------------------------------------
# Terminal Initialization Function
# ------------------------------------------------------------------------------

# Initializes the console keymap and font (user defined variables) and the system time
terminal_init() {
    clear
    
    info_print "Changing console keyboard layout to $keymap . . . ."
    loadkeys "$keymap"
    sleepy 2
    
    info_print "Changing console font to $font . . . ."
    setfont "$font"
    sleepy 2
    
    info_print "Configuring system date and time . . . ."
    timedatectl set-ntp true
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Partition Disk Function
# ------------------------------------------------------------------------------

# Partitions the device name provided in the user variables
part_disk() {
    clear
    
    info_print "Arch Linux will be installed on the following disk: $device"
    sleepy 1
    input_print "This operation will wipe and delete $device  ....  Do you agree to proceed [y/N]   "
    read -r disk_response
    if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
        error_print "Quitting."
        sleepy 1
        error_print "Nice job breaking it. Hero."
        exit
    fi

    info_print "Wiping $device . . . ."
    sgdisk -Z "$device"
    wipefs --all --force "$device"
    sleepy 2

    info_print "Partitioning $device . . . ."
    sgdisk -o "$device"
    sgdisk -n 0:0:+1G -t 0:ef00 "$device"
    sgdisk -n 0:0:0 -t 0:8304 "$device"
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Format & Mount Partitions Function
# ------------------------------------------------------------------------------i

# Formats the partitions and mounts them
format_mount() {
    clear
    
    # Format the partitions
    info_print "Formatting the root partition as ext4 . . . ."
    mkfs.ext4 -FF "$rootdev"
    sleepy 2

    info_print "Formatting the boot partition as fat32 . . . ."
    mkfs.fat -F 32 "$bootdev"
    sleepy 2

    # Mount the partitions
    info_print "Mounting the boot and root partitions . . . ."
    mount "$rootdev" /mnt
    mount --mkdir "$bootdev" /mnt/boot
    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Base System Function
# ------------------------------------------------------------------------------i

# Installation of the necessary packages for a functioning base system
install_base() {
    clear

    # Update the package list for the base system to include the correct microcode and the additional (optional) kernel
    base_system+=("$microcode" "linux-$kernel")

    # Pacstrap install the base system
    info_print "Beginning install of the base system packages . . . ."
    sleepy 2
    info_print "An $cpu CPU has been detected; the $cpu microcode will be installed."
    sleepy 2
    pacstrap -K /mnt "${base_system[@]}"
    info_print "Base system installed . . . ."

    sleepy 5
}


# ------------------------------------------------------------------------------
# Set System Time Zone Function
# ------------------------------------------------------------------------------

# Set the system timezone
set_tz() {
    clear
    
    info_print "Setting the timezone to $timezone . . . ."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
    arch-chroot /mnt hwclock --systohc

    sleepy 3
}


# ------------------------------------------------------------------------------
# Localization & Virtual Console Function
# ------------------------------------------------------------------------------

# Sets the locale and the keymap and font for the virtual console
set_locale() {
    clear
    
    info_print "Setting locale to $locale . . . ."
    arch-chroot /mnt sed -i "s/#$locale/$locale/g" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$locale" > /mnt/etc/locale.conf
    sleepy 2
    
    info_print "Configuring vconsole . . . ."
    echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
    echo "FONT=$font" >> /mnt/etc/vconsole.conf
    sleepy 3
}


# ------------------------------------------------------------------------------
# Network Configuration Function
# ------------------------------------------------------------------------------

# Configures the network files and enables NetworkManager
network_config() {
    clear

    info_print "Setting the hostname to $hostname . . . ."
    echo "$hostname" > /mnt/etc/hostname
    sleepy 1

    info_print "Creating the /etc/hosts file . . . ."
cat > /mnt/etc/hosts <<EOF
127.0.0.1      localhost
::1            localhost
127.0.1.1      $hostname.localdomain     $hostname
EOF
    sleepy 1

    info_print "Configuring NetworkManager . . . ."
cat > /mnt/etc/NetworkManager/conf.d/no-systemd-resolved.conf <<EOF
[main]
systemd-resolved=false
EOF
    sleepy 1
        
    info_print "Enabling NetworkManager service . . . ."
    arch-chroot /mnt systemctl enable NetworkManager
    sleepy 3
}


# ------------------------------------------------------------------------------
# Bootloader Configuration Function
# ------------------------------------------------------------------------------

# Configure the bootloader
bootloader_config() {
    clear

    info_print "Installing systemd-boot . . . ."
    arch-chroot /mnt systemd-machine-id-setup
    arch-chroot /mnt bootctl install
    sleepy 2
    
    info_print "Configuring systemd-boot . . . ."
cat > /mnt/boot/loader/loader.conf <<EOF
default  arch-linux.conf
timeout  3
console-mode max
editor   no
EOF

cat > /mnt/boot/loader/entries/arch-linux.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /$microcode_img
initrd /initramfs-linux.img
options zswap.enabled=0 rw quiet
EOF

cat > /mnt/boot/loader/entries/arch-linux-fallback.conf <<EOF
title Arch Linux (fallback)
linux /vmlinuz-linux
initrd /$microcode_img
initrd /initramfs-linux-fallback.img
options zswap.enabled=0 rw quiet
EOF

    if [ -n "$kernel" ] ; then

cat > /mnt/boot/loader/entries/arch-linux-"$kernel".conf <<EOF
title Arch Linux ${kernel^^}
linux /vmlinuz-linux-$kernel
initrd /$microcode_img
initrd /initramfs-linux-$kernel.img
options zswap.enabled=0 rw quiet
EOF

    fi
    sleepy 2

    info_print "Creating systemd-boot pacman hook . . . ."
    mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/95-systemd-boot.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot . . . .
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# mkinitcpio Configuration Function
# ------------------------------------------------------------------------------

# Configure and regenerate mkinitcpio
mkinit_config() {
    clear

    info_print "Configuring mkinitcpio . . . ."
    cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
cat > /mnt/etc/mkinitcpio.conf <<EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block filesystems fsck)
EOF
    sleepy 1

    info_print "Regenerating initramfs files . . . ."
    arch-chroot /mnt mkinitcpio -P
    sleepy 3
}


# ------------------------------------------------------------------------------
# ZRAM Configuration Function
# ------------------------------------------------------------------------------

# Configure and optimize ZRAM
zram_config() {
    clear

    info_print "Configuring ZRAM . . . ."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
    sleepy 1

    info_print "Optimizing ZRAM . . . ."
cat > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

    sleepy 3
}


# ------------------------------------------------------------------------------
# Pacman Configuration Function
# ------------------------------------------------------------------------------

# Configure pacman
pacman_config() {
    clear

    info_print "Configuring pacman . . . ."
    cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
cat > /mnt/etc/pacman.conf <<EOF
# Refer to pacman.conf(5) manpage for additional information

[options]
HoldPkg = pacman glibc
Architecture = auto

# Misc options
UseSyslog
Color
CheckSpace
VerbosePkgLists
ParallelDownloads = 7
ILoveCandy

SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Display Drivers Function
# ------------------------------------------------------------------------------

# Install the appropriate display drivers based on the provided gpu type
install_display() {
    clear
    
    if [ "$gpu" == "amd" ] ; then
        info_print "Installing display drivers for an AMD GPU . . . ."
        sleepy 2
        arch-chroot /mnt pacman -S --needed --noconfirm mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver 
        arch-chroot /mnt pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-radeon lib32-vulkan-icd-loader lib32-libva-mesa-driver
    else
        info_print "Installing display drivers for an Intel GPU . . . ."
        sleepy 2
        arch-chroot /mnt pacman -S --needed --noconfirm mesa vulkan-intel vulkan-icd-loader intel-media-driver
        arch-chroot /mnt pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-intel lib32-vulkan-icd-loader
    fi

    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Audio Drivers Function
# ------------------------------------------------------------------------------

# Installs any necessary audio firmware and install the pipewire packages
# The pipewire systemd services will be enabled in the install_user.sh script
install_audio() {
    clear
    
    awk '{print $1}' /proc/modules | grep -c snd_sof | read count_mod
    if [ $count_mod != "0" ] ; then 
        info_print "The sof-firmware package is required for your system. Installing now . . . ."
        sleepy 2
        arch-chroot /mnt pacman -S --needed --noconfirm sof-firmware
    fi
    sleepy 2

    for x in "${alsa_array[@]}" ; do
        awk '{print $1}' /proc/modules | grep -c "$x" | read count_mod2
        if [ $count_mod2 != "0" ] ; then
            info_print "The alsa-firmware package is required for your system. Installing now . . . ."
            sleepy 2
            arch-chroot /mnt pacman -S --needed --noconfirm alsa-firmware
            sleepy 2
            break 
        fi
    done 

    clear
    info_print "Installing pipewire packages . . . ."
    sleepy 2
    arch-chroot /mnt  pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire libpulse
    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Essential Packages and Fonts Function
# ------------------------------------------------------------------------------

# Installs essential system packages and fonts
install_essentials() {
    clear

    info_print "Installing system fonts . . . ."
    sleepy 2
    arch-chroot /mnt pacman -S --needed --noconfirm "${fonts[@]}"
    sleepy 2

    clear
    info_print "Installing essential system packages . . . ."
    sleepy 2
    arch-chroot /mnt pacman -S --needed --noconfirm "${essentials[@]}"
    sleepy 3   
}


# ------------------------------------------------------------------------------
# Miscellaneous Configuration Function
# ------------------------------------------------------------------------------

# Configures miscellaneous files associated with the installed essential packages
misc_config() {
    clear

    info_print "Configuring lograte.conf . . . ."
    arch-chroot /mnt sed -i "s/#compress/compress/g" /etc/logrotate.conf
    sleepy 2

    info_print "Configuring nsswitch.conf . . . ."
    arch-chroot /mnt sed -i "s/mymachines/mymachines mdns_minimal [NOTFOUND=return]/g" /etc/nsswitch.conf
    sleepy 3
}


# ------------------------------------------------------------------------------
# Enable System Services Function
# ------------------------------------------------------------------------------

# Enables system services
enable_services() {
    clear

    info_print "Enabling avahi, bluetooth, cups, firewalld, and timesyncd services . . . ."
    arch-chroot /mnt systemctl enable avahi-daemon bluetooth cups firewalld systemd-timesyncd
    sleepy 2

    info_print "Enabling archlinux-keyring, fstrim, and logrotate timers . . . ."
    arch-chroot /mnt systemctl enable archlinux-keyring-wkd-sync.timer fstrim.timer logrotate.timer
    sleepy 3
}


# ------------------------------------------------------------------------------
# Create Main User Function
# ------------------------------------------------------------------------------

# Create the main user and configure sudo rights
main_user() {
    clear

    info_print "Configuring sudo rights . . . ."
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/wheelnopasswd
    echo "Defaults passwd_timeout=0" > /mnt/etc/sudoers.d/defaults
    echo "Defaults insults" >> /mnt/etc/sudoers.d/defaults
    sleepy 2

    info_print "Hardening log-in protections . . . ."
    echo "auth optional pam_faildelay.so delay=4000000" >> /mnt/etc/pam.d/system-login
    sleepy 2
    
    info_print "Adding the user $username to the system with root privilege . . . ."
    arch-chroot /mnt useradd -m -G wheel "$username"
    sleepy 2
    
    input_print "Set the user password for $username . . . ."
    arch-chroot /mnt passwd "$username"
    #echo "$username:$userpass" | arch-chroot /mnt chpasswd
}


# ------------------------------------------------------------------------------
# Begin Install
# ------------------------------------------------------------------------------

clear

# Welcome message
info_print "Hello and, again, welcome to the Aperture Science computer-aided enrichment center."
sleepy 1
info_print "Beginning Arch Linux installation . . . ."
sleepy 3

# Check for working internet connection; will exit script if there is no connection
check_connection

# Initialize tty terminal and system clock
terminal_init

# Partition the disk
part_disk

# Format and mount the partitions
format_mount

# Install base system
install_base

# Generate fstab
clear
info_print "Generating fstab . . . ."
genfstab -U /mnt >> /mnt/etc/fstab
sleepy 3

# Set timezone
set_tz

# Localization & virtual console configuration
set_locale

# Network configuration
network_config

# Bootloader configuration
bootloader_config

# mkinitcpio configuration
mkinit_config

# zram configuration
zram_config

# Pacman configuration
pacman_config

# System update
clear
info_print "Completing a full system update . . . ."
arch-chroot /mnt pacman -Syyu --noconfirm
sleepy 3

# Install display drivers
install_display

# Install audio drivers
install_audio

# Install essential packages and fonts
install_essentials

# Miscellaneous configuration
misc_config

# Enable services
enable_services

# Root password
clear
input_print "Set the ROOT password . . . ." 
arch-chroot /mnt passwd
sleepy 1

# Create main user
main_user

# Finish base install
clear
info_print "Base installation is complete."
sleepy 1
info_print "The system will automatically shutdown now."
sleepy 1
info_print "After shutdown, remove the USB drive, turn on the system, and login as the main user."
sleepy 3
umount -R /mnt
shutdown now
