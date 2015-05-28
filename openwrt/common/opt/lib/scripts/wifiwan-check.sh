#!/bin/bash

. /lib/functions/network.sh

## if wan is wireless
unset _COUNT
while network_get_physdev _IFNAME wan && [[ ! $_IFNAME =~ 'wlan' ]]; do
  let _COUNT++
  if [[ $_COUNT -ge 30 ]]; then
    echo 'wan is not wifi'
    exit
  fi
  echo "waiting for wan conf.. $((30-$_COUNT))"
  sleep 1
done

checkWan() {
  if [[ "$(iw $_IFNAME link)" =~ 'Connected ' ]]; then
    if [[ "$(route | grep $_IFNAME)" =~ '0.0.0.0' ]]; then
      return 1
    fi
  fi
  return 0
}

## if wan is connected and is default gw
unset _COUNT
while checkWan; do
  let _COUNT++
  if [[ $_COUNT -ge 60 ]]; then
    echo 'wan wifi is dead, disabling'
    uci set wireless.@wifi-iface[-1].disabled=1
    uci commit wireless
    wifi
    exit
  fi
  echo "waiting for wan wifi.. $((60-$_COUNT))"
  sleep 1
done

echo 'wan wifi is connected'
exit
