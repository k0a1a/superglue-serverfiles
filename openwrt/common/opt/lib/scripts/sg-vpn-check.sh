#!/bin/bash

## check if SG openvpn connection is established:
##   have 10.4.0.0 network
##   can ping 10.4.0.1 host
## timeout after 60 seconds

while ! grep -q '0A040000' /proc/net/route; do
  [[ $COUNT -le 10 ]] || exit 1
  sleep 1
  let COUNT++
done

ping -q -c1 -w5 10.4.0.1 &>/dev/null || exit 2

