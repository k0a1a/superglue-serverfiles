#!/bin/sh

sleep 2

/sbin/wifi
/etc/init.d/network reload
#/etc/init.d/dnsmasq reload

exit 0
