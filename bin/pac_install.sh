#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

clear

mapfile -t packages < $1

sudo pacman -S --needed --noconfirm "${packages[@]}"
