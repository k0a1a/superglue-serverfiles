#!/bin/sh

sleep 3

/sbin/wifi
/etc/init.d/network restart
/etc/init.d/dnsmasq restart

exit 0
