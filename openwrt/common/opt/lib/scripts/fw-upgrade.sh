#!/bin/bash

RE=$2

sleep 2

[[ $RE == 'on' ]] && RE='-n' || RE=''

sysupgrade $RE -q $1 ##> /tmp/fw-upgrade.log

exit 0
