#!/bin/bash

[[ $(uci get dyndns.superglue.enable) == '1' ]] || exit 1

_DOMAIN=$(uci get dyndns.superglue.domain) &&
_SUB=$(uci get dyndns.superglue.subdomain) &&
_UPDATEURL=$(uci get dyndns.superglue.updateurl) &&
_CLIENT=$(uci get dyndns.superglue.client)

## if we are on Superglue VPN talk to the VPN gateway
if grep -q '0A040000' /proc/net/route; then 
  _UPDATEURL='http://10.4.0.1/ddns/update'
fi

_JSON='{"jsonrpc": "2.0", "client": "'$_CLIENT'", "sub": "'$_SUB'", "domain": "'$_DOMAIN'"}'

_OUT=$(/usr/bin/curl -s -w '\t%{http_code}' -k -d "data=$_JSON" "$_UPDATEURL" 2>&1)
_ERR=$?

if [[ $_ERR -gt 0 ]]; then
  printf -v _TIME '%(%Y-%m-%d %H:%M:%S)T' -1
  printf '%b\n' "$_TIME: $_OUT" >> "/www/log/dyndns.log"
  printf '%s' "$_ERR,Updater error"
else
  printf '%s' "$_OUT"
fi

exit $_ERR
