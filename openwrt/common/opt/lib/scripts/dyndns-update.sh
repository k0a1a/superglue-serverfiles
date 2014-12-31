#!/bin/bash

uci -q get superglue.dyndns.disabled && exit 0

set -e
_UPDATEURL=$(uci get superglue.dyndns.updateurl)
_TOKEN=$(uci get superglue.dyndns.token)
set +e

/usr/bin/wget -q "${_UPDATEURL}${_TOKEN}" -O - >> /www/log/dyndns.log

exit 0
