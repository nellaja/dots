#!/usr/bin/env bash
#
# bluetooth.sh - check power status of bluetooth controller
#             
#
# USAGE: bluetooth.sh
#
# TAGS:
#  Name      Type  Return
#  -------------------------------------------
#  {pstatus} string power on or off status
#
# Examples configuration:
#
#  - script:
#      path: /absolute/path/to/bluetooth.sh
#      args: []
#      content:
#        map:
#          default: { string: { text: "on" } }
#          conditions:
#            pstatus == "off": {string: {text: "off"}}


declare pstatus

# Error message in STDERR
_err() {
  printf -- '%s\n' "[$(date +'%Y-%m-%d %H:%M:%S')]: $*" >&2
}

# Display tags before yambar fetches the status update
printf -- '%s\n' "status|string|on"
printf -- '%s\n' ""

while true; do
  # Change interval
  # NUMBER[SUFFIXE]
  # Possible suffix:
  #  "s" seconds / "m" minutes / "h" hours / "d" days
  interval="2s"


  # Get power status of bluetooth controller
  pstatus=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

  printf -- '%s\n' "status|string|${pstatus}"
  printf -- '%s\n' ""

  sleep "${interval}"

done

unset -v pstatus
unset -f _err
