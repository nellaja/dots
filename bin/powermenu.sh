#!/usr/bin/env bash

entries="󰍃 Logout\n󰜉 Reboot\n󰤂 Shutdown"

selected=$(echo -e $entries | fuzzel --dmenu | awk '{print tolower($2)}')


case $selected in
  logout)
    swaymsg exit;;
  reboot)
    exec systemctl reboot;;
  shutdown)
    exec systemctl poweroff;;
esac
  
