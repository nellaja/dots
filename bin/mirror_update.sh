#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

sudo reflector --verbose --protocol https --country US,UK,Canada,France,Germany --latest 19 --score 11 --sort rate --save /etc/pacman.d/mirrorlist
