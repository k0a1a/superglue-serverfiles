#!/bin/bash

## fetch and update contents of /www/ from git.superglue.it

_PWD=$(pwd)
_USER='httpd'
_WWW='/www'
_URL='http://git.superglue.it/superglue/serverside/repository/archive.tar.gz'
_ARC=$(curl -Is $_URL | awk -F\" '/serverside/ { print $2 }')

cd /tmp

if [[ -z "$_ARC" ]]; then
  echo 'error fetching archive version'
  exit 1
fi

if [[ ! -e "$_ARC" ]]; then
  echo -n "$(date): fetching $_ARC "
  curl -OJs "$_URL" || exit 1
  echo "OK"
else 
#  echo 'im up-to-date'
  exit 0
fi

_DIR=($(tar xvzf $_ARC 2>/dev/null))

if [[ -z "$_DIR" ]]; then
 echo 'error extracting archive'
 exit 1
fi

cp -Rf "$_DIR"/* $_WWW/ &&
chown -R $_USER $_WWW/* &&
_OUT="$(date): update OK"

echo "$_OUT"

if [[ ! -z "_OUT" ]]; then 
	echo -e "Subject: pull-serverside-repo.sh\n$_ARC\n$_OUT" | sendmail -f'sg1@superglue.it' -t -s192.168.1.100 robot@k0a1a.net
fi

## remove old archives and unpacked directory
for i in $(ls -1d serverside* | grep -v "$_ARC"); do rm -Rf "$i"; done 

cd $_PWD

exit 0

