#!/bin/sh

sleep 2

/sbin/wifi
/etc/init.d/network reload
/etc/init.d/dnsmasq reload

#sleep 2

#/opt/lib/scripts/wifiwan-check.sh >> /tmp/wifi.log

exit 0
