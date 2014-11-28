#!/bin/bash

function iwScan() {
  set -o noglob
  local AP S
  while read -r AP; do
    [[ "${AP//'SSID: '*}" == '' ]] && printf '%b' "${AP/'SSID: '}\n"
    [[ "${AP//'signal: '*}" == '' ]] && ( S=( ${AP/'signal: '} ); printf '%b' "${S[0]},";)
    [[ "${AP//'last seen: '*}" == '' ]] && ( S=( ${AP/'last seen: '} ); printf '%b' "${S[0]},";)
  done <<< "$(iw wlan0 scan)"
  set +o noglob
}
