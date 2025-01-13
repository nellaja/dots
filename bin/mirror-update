#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

clear

sudo reflector --verbose --protocol https --country US,UK,Canada,France,Germany --latest 19 --score 11 --sort rate --save /etc/pacman.d/mirrorlist
