#!/bin/bash

## SuperGlue project | http://superglue.it | 2014 | GPLv3
## http://git.superglue.it/superglue/serverfiles
##
## iw-scan.sh - scan for wireless networks 

iwScan() {
  set -o noglob
  local AP
  local S
  while read -r AP; do
    [[ "${AP//'SSID: '*}" == '' ]] && printf '%b' "${AP/'SSID: '}\n"
    [[ "${AP//'signal: '*}" == '' ]] && ( S=( ${AP/'signal: '} ); printf '%b' "${S[0]},";)
    [[ "${AP//'last seen: '*}" == '' ]] && ( S=( ${AP/'last seen: '} ); printf '%b' "${S[0]},";)
  done <<< "$(runSuid iw wlan0 scan)"
  set +o noglob
}

iwScanJ() {
  set -o noglob
  local S=$(runSuid "ubus -S call iwinfo scan '{\"device\":\"wlan0\"}'")
  printf '%b' "$S"
  set +o noglob
}

#iwScanJ
