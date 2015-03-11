#!/bin/bash

## SuperGlue project | http://superglue.it | 2014 | GPLv3
## http://git.superglue.it/superglue/serverfiles
##
## iw-scan.sh - scan for wireless networks 

iwScan() {
  set -o noglob
  local S=$(ubus -S call iwinfo scan '{"device":"wlan0"}')
  printf '%b' "$S"
  set +o noglob
}

