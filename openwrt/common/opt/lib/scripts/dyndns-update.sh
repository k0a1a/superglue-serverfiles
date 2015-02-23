#!/bin/bash

set -e
uci -q get superglue.dyndns.disabled && exit 1
uci -q get superglue.dyndns.domainname || exit 1

_UPDATEURL=$(uci get superglue.dyndns.updateurl)
/usr/bin/wget -q "${_UPDATEURL}" -O - >> /www/log/dyndns.log

exit 0
