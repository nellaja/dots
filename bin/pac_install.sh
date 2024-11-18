#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

clear

mapfile -t packages < $1

sudo pacman -S --needed --noconfirm "${packages[@]}"
