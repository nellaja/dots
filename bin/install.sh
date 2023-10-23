#!/usr/bin/env bash

set -e
shopt -s extglob

# Cleaning the TTY
clear

# ------------------------------------------------------------------------------
# Variable Definitions - User Defined
# ------------------------------------------------------------------------------

keymap="us"                    # Console keymap setting (localectl list-keymaps)
font="ter-120b"                # Console font (ls -a /usr/share/kbd/consolefonts)
device="/dev/nvme0n1"          # Drive for install (e.g., /dev/nvme0n1, /dev/sda)
kernel="lts"                   # Additional kernel to install (do not include linux prefix) 
timezone="America/New_York"    # Location timezone
locale="en_US.UTF-8"           # Locale and language variable 
hostname="adventure"           # Machine hostname
username="aj"                  # Main user
gpu="amd"                      # GPU manufacturer (amd or intel)[lspci | grep VGA | sed 's/^.*: //g']    
aur="aura"                     # AUR helper

# Packages groups
base_system=(base base-devel linux linux-firmware vim terminus-font git networkmanager efibootmgr zram-generator reflector)


# ------------------------------------------------------------------------------
# Variable Definitions - Auto Defined
# ------------------------------------------------------------------------------

# Define partition numbers for boot and root partitions based on device type
if [ "${device::8}" == "/dev/nvm" ] ; then
    bootdev="${device}p1"
    rootdev="${device}p2"
else
    bootdev="${device}1"
    rootdev="${device}2"
fi

# Determine CPU manufacturer
cpu=$(lscpu | grep "Vendor ID:")
if [ "$cpu" == *"AuthenticAMD"* ] ; then
    microcode="amd-ucode"
    microcode_img="amd-ucode.img"
else
    microcode="intel-ucode"
    microcode_img="intel-ucode.img"
fi


# ------------------------------------------------------------------------------
# Variable Definitions - Universal
# ------------------------------------------------------------------------------

alsa_array=(snd_asihpi snd_cs46xx snd_darla20 snd_darla24 snd_echo3g snd_emu10k1 snd_gina20 snd_gina24 snd_hda_codec_ca0132 snd_hdsp snd_indigo snd_indigodj snd_indigodjx snd_indigoio snd_indigoiox snd_layla20 snd_layla24 snd_mia snd_mixart snd_mona snd_pcxhr snd_vx_lib)


# ------------------------------------------------------------------------------
# Pretty Print Functions
# ------------------------------------------------------------------------------

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}


# ------------------------------------------------------------------------------
# Internet Connection Functions
# ------------------------------------------------------------------------------

# Exit the script if there is no internet connection
not_connected(){
    clear
    error_print "No network connection!!!  Exiting now."
    error_print "This is your fault. It didn't have to be like this."
    exit 1
}

# Check for working internet connection
check_connect(){
    clear
    info_print "Trying to ping archlinux.org..."
    $(ping -c 3 archlinux.org &>/dev/null) ||  not_connected
    info_print "Connection good!"
    info_print "Thank you for helping us help you help us all." && sleep 3
}


# ------------------------------------------------------------------------------
# Terminal Initialization Function
# ------------------------------------------------------------------------------

# Initialization of the terminal keymap, font, and system time
terminal_init() {
    loadkeys "$keymap"
    setfont "$font"
    timedatectl set-ntp true
    info_print "Date/Time status is . . . "
    timedatectl status
    sleep 3
}


# ------------------------------------------------------------------------------
# Partition Disk Function
# ------------------------------------------------------------------------------

part_disk() {
    info_print "Arch Linux will be installed on the following disk: $device"
    input_print "This will wipe and delete the $device. Do you agree to proceed [y/N]"    
    read -r disk_response
    if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
        error_print "Quitting."
        exit
    fi

    info_print "Wiping $device"
    sgdisk -Z "$device"
    wipefs -a "$device"

    info_print "Partitioning $device"
    sgdisk -o "$device"
    sgdisk -n 0:0:+1G -t 0:ef00 "$device"
    sgdisk -n 0:0:0 -t 0:8304 "$device"

    info_print "Status of the partitioned disk:"
    fdisk -l "$device"

    sleep 3
}


# ------------------------------------------------------------------------------
# Format & Mount Partitions Function
# ------------------------------------------------------------------------------i

format_mount() {
    # Format the partitions
    info_print "Formatting the root partition."
    mkfs.ext4 "$rootdev"

    info_print "Formatting the boot partition."
    mkfs.fat -F 32 "$bootdev"

    # Mount the partitions
    info_print "Mounting the boot and root partitions."
    mount "$rootdev" /mnt
    mount --mkdir "$bootdev" /mnt/boot

    sleep 3
}


# ------------------------------------------------------------------------------
# Install Base System Function
# ------------------------------------------------------------------------------i

install_base() {
    clear
    base_system+=("$microcode" "$kernel")
    pacstrap -K /mnt "${base_system[@]}"
    info_print "Base system installed.  Press any key to continue..."; read empty
}


# ------------------------------------------------------------------------------
# Set System Time Zone Function
# ------------------------------------------------------------------------------

set_tz() {
    clear
    info_print "Setting timezone to $timezone..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    arch-chroot /mnt date
    info_print "Press any key to continue..."; read empty
}


# ------------------------------------------------------------------------------
# Localization & Virtual Console Function
# ------------------------------------------------------------------------------

set_locale() {
    clear
    info_print "Setting locale to $locale..."
    arch-chroot /mnt sed -i "s/#$locale/$locale/g" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$locale" > /mnt/etc/locale.conf
    cat /mnt/etc/locale.conf
    info_print "Press any key to continue..."; read empty

    info_print "Configuring vconsole..."
    echo "KEYMAP=$keymap" > mnt/etc/vconsole.conf
    echo "FONT=$font" >> mnt/etc/vconsole.conf
    cat /mnt/etc/vconsole.conf
    info_print "Press any key to continue..."; read empty
}


# ------------------------------------------------------------------------------
# Network Configuration Function
# ------------------------------------------------------------------------------

network_config() {
    clear
    echo "$hostname" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<EOF
127.0.0.1      localhost
::1            localhost
127.0.1.1      $hostname.localdomain     $hostname
EOF

    info_print "/etc/hostname and /etc/hosts files configured..."
    cat /mnt/etc/hostname 
    cat /mnt/etc/hosts
    info_print "Press any key to continue"; read empty
    arch-chroot /mnt systemctl enable NetworkManager.service
}


# ------------------------------------------------------------------------------
# Bootloader Configuration Function
# ------------------------------------------------------------------------------

bootloader_config() {
    arch-chroot /mnt systemd-machine-id-setup
    arch-chroot /mnt bootctl install

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
title Arch Linux $(kernel^^)
linux /vmlinuz-linux-$kernel
initrd /$microcode_img
initrd /initramfs-linux-$kernel.img
options zswap.enabled=0 rw quiet
EOF

    fi

    mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/95-systemd-boot.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF

    arch-chroot /mnt systemctl set-default multi-user.target
}


# ------------------------------------------------------------------------------
# mkinitcpio Configuration Function
# ------------------------------------------------------------------------------
mkinit_config() {
    cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
cat > /mnt/etc/mkinitcpio.conf <<EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block filesystems fsck)
EOF

    arch-chroot /mnt mkinitcpio -P
}


# ------------------------------------------------------------------------------
# ZRAM Configuration Function
# ------------------------------------------------------------------------------

zram_config() {

cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

    arch-chroot /mnt systemctl daemon-reload
    arch-chroot /mnt systemctl start /dev/zram0

cat > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
}


# ------------------------------------------------------------------------------
# Reflector Configuration Function
# ------------------------------------------------------------------------------

reflector_config() {
    cp /mnt/etc/xdg/reflector/reflector.conf /mnt/etc/xdg/reflector/reflector.conf.bak
cat > /mnt/etc/xdg/reflector/reflector.conf <<EOF
--save /etc/pacman.d/mirrorlist
--protocol https
--country US,CA
--completion-percent 100
--age 24
--delay 1
--score 11
--fastest 7
EOF

    mkdir /mnt/etc/systemd/system/reflector.timer.d
cat > /mnt/etc/systemd/system/reflector.timer.d/override.conf <<EOF
[Timer]
OnCalendar=
OnCalendar=quarterly
RandomizedDelaySec=4h
EOF

    arch-chroot /mnt systemctl enable reflector.timer
    arch-chroot /mnt systemctl start reflector.timer
}


# ------------------------------------------------------------------------------
# Pacman Configuration Function
# ------------------------------------------------------------------------------

pacman_config() {
    cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak

cat > /mnt/etc/pacman.conf << EOF

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
}


# ------------------------------------------------------------------------------
# Create Main User Function
# ------------------------------------------------------------------------------

main_user() {
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheelnopasswd
    echo "Defaults passwd_timeout=0" > /etc/sudoers.d/defaults
    echo "Defaults insults" >> /etc/sudoers.d/defaults
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel "$username"
    info_print "Set the user password for $username."
    arch-chroot /mnt passwd "$username"
    #echo "$username:$userpass" | arch-chroot /mnt chpasswd
}


# ------------------------------------------------------------------------------
# Install Display Drivers Function
# ------------------------------------------------------------------------------
install_display() {
    if [ "$gpu" == "amd" ] ; then
        arch-chroot /mnt pacman -S --needed --noconfirm mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver 
        arch-chroot /mnt pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-radeon lib32-vulkan-icd-loader lib32-libva-mesa-driver
    else
        arch-chroot /mnt pacman -S --needed --noconfirm mesa vulkan-intel vulkan-icd-loader intel-media-driver
        arch-chroot /mnt pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-intel lib32-vulkan-icd-loader
    fi
}


# ------------------------------------------------------------------------------
# Install Audio Drivers Function
# ------------------------------------------------------------------------------

install_audio() {
    if [ awk '{print $1}' /proc/modules | grep -q "snd_sof" ] ; then
        arch-chroot /mnt pacman -S --needed --noconfirm sof-firmware
    fi

    for x in "${alsa_array[@]}" ; do
        if [ awk '{print $1}' /proc/modules | grep -q "$x" ] ; then
            arch-chroot /mnt pacman -S --needed --noconfirm alsa-firmware
            break 
        fi
    done 

    arch-chroot /mnt  pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire libpulse
}


# ------------------------------------------------------------------------------
# Install AUR Helper Function
# ------------------------------------------------------------------------------

install_aur() {
    if [ -n "$aur" ] ; then
        # Installing AUR helper
        info_print "Installing AUR helper ($aur)"
        cd /tmp
        sudo -u "$username" git clone "https://aur.archlinux.org/$aur.git"
        cd "$aur"
        sudo -u "$username" makepkg --noconfirm -si
    fi
}


# ------------------------------------------------------------------------------
# Begin Install
# ------------------------------------------------------------------------------

clear

# Welcome message
info_print "Hello and, again, welcome to the Aperture Science computer-aided enrichment center."

# Check for working internet connection; will exit script if there is no connection
check_connection

# Initialize tty terminal and system clock
terminal_init

# Partition the disk
part_disk

# Format and mount the partitions
format_mount

# Update the mirrors
info_print "Updating the mirrors..."
reflector --country US,CA --protocol https --completion-percent 100 --age 24 --delay 1 --score 11 --fastest 7 --save /etc/pacman.d/mirrorlist

# Install base system
install_base

# Generate fstab
info_print "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Set timezone
set_tz

# Localization & virtual vonsole configuration
set_locale

# Network configuration
network_config

# Bootloader configuration
bootloader_config

# mkinitcpio configuration
mkinit_config

# zram configuration
zram_config

# Reflector configuration
reflector_config

# Pacman configuration
pacman_config

# System update
arch-chroot /mnt pacman -Syyu --noconfirm

# Root password
info_print "Setting ROOT password..." 
arch-chroot /mnt passwd 

# Create main user
main_user

# Install display drivers
install_display

# Install audio drivers
install_audio

# Install AUR helper
install_aur

# Install desktop packages
install_desktop

# Install extra packages
install_extras

# Enable Services
enable_services

# Clean up
cleanup




