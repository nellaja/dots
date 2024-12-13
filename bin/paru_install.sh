#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

clear

mapfile -t packages < $1

paru -S --noconfirm "${packages[@]}"
