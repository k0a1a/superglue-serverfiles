#!/bin/bash

_DOMAIN=$1
_PSK=$(<../host.psk)
_DATE=$(date +%s)

_SGVPN='10.0.4.2'
#_SGVPN=''

trim() {
  while read line; do
    if [[ "$line" == "${line//#}" && "$line" == "${line//-----}" ]]; then
      echo -n $line
    fi
  done <<< "$_PSK"
}

_MD5=$(trim | md5sum) 
_MD5=${_MD5// *}

_DOMAIN=$(printf '%s' $_DOMAIN | base64)

_JSON='{"jsonrpc": "2.0", "client": "'$_MD5'", "domain": "'$_DOMAIN'", "sgvpn": "'$_SGVPN'"}'

#wget -q --post-data "data=$_JSON" https://superglue.it/ddns/update -O -
curl -k -d "data=$_JSON" https://superglue.it/ddns/update
