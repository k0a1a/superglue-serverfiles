#!/bin/ash

## handling of Btrfs partition
##
## parse blkid output 
## find Btrfs partition with 'sg-data' label
## mount it to /www

_TARGET_LABEL='sg-data'
_TARGET_MOUNT='/www'
_MOUNT_PARAMS='rw,noatime,nodiratime,sync'

detectBtrfs() {
  IFS=$'\n'
  local _P _L
  for _L in $(blkid); do
    IFS=' '
    for _P in $_L; do
      if [ "${_P//dev/}" != "${_P}" ]; then
        _DEV="${_P/:}"
      else 
        eval "_${_P/=*}=\"${_P/*=/}\""
      fi
      if [ "$_TYPE" != "" ] && [ -z "${_TYPE/btrfs}" ] && [ -z "${_LABEL/$1}" ]; then
        #echo "$_DEV $_UUID"
        return 0
      fi
    done
  done
  IFS=$OFS
  return 1
}

if mountpoint -q $_TARGET_MOUNT; then
  echo "/www is already a mountpoint"
  exit 1
fi

if ! detectBtrfs $_TARGET_LABEL; then 
  echo "no Btrfs partition with label $_TARGET_LABEL was found"
  exit 1
fi

if ! mount -o $_MOUNT_PARAMS $_DEV $_TARGET_MOUNT; then
  echo "error mounting $_DEV partition"
  exit 1
fi

if ! mountpoint -q $_TARGET_MOUNT; then
  echo "$_TARGET_MOUNT is not a mountpoint.."
  exit 1
fi

## reload Lighttpd since it might have had open files in /www
killall -HUP lighttpd

exit 0
