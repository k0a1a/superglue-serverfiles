#!/bin/sh

sleep 2

sysupgrade -q $1 ##> /tmp/fw-upgrade.log

exit 0
