#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

clear

# Find the configured esp
esp=$(bootctl -p)

# Prepare the efi partition for kernel-install
machineid=$(cat /etc/machine-id)
if [[ ${machineid} ]]; then
    mkdir ${esp}/${machineid}
else
    echo "Failed to get the machine ID"
fi

# Run kernel install for all the installed kernels
reinstall-kernels
