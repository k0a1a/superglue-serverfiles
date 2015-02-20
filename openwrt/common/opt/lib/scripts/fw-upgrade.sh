#!/bin/sh

sleep 3

sysupgrade -v $1 > /tmp/fw-upgrade.log

exit 0

