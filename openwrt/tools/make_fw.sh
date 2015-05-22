#!/bin/bash

## SuperGlue project | http://superglue.it | 2014-2015 | GPLv3
## http://git.superglue.it/superglue/serverfiles
##
## make_fw.sh - Superglue firmware image building script
##
## Needs:
## - OpenWRT ImageBuilder blob:
##    http://downloads.openwrt.org/barrier_breaker/14.07/ar71xx/generic
##    or http://downloads.openwrt.org/snapshots/trunk/ar71xx
## - Fetch (needed) packages:
##    https://downloads.openwrt.org/barrier_breaker/14.07/ar71xx/generic/packages
## - Superglue serverfiles local repo (which this script is a part of):
##    http://git.superglue.it/superglue/serverfiles/tree/master

## errors are futile
set -e

## make sure we are running from the upper level directory
[[ $(pwd) == $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ]] && (echo "ERROR: must be run as ./tools/$(basename $0), exiting"; exit 1;)

_PWD=$(pwd)
_IMAGEBUILDER="$_PWD/../../../openwrt/OpenWrt-ImageBuilder-ar71xx_generic-for-linux-x86_64"
_BUILDS="$_PWD/../../../sg-builds"

[[ -e $_IMAGEBUILDER ]] || (echo 'ImageBuilder is missing'; exit 1;)
[[ -e $_BUILDS ]] || (echo 'Builds directory is missing'; exit 1;)

set +e

## dirs with platform specific files
_TARGETS='DIR505A1 TLWR710' #WRT160NL

## dir with common files
_COMMON='common'

_SG_REVISION="$_PWD/superglue.revision"
if [[ -e $_SG_REVISION ]]; then
  source $_SG_REVISION
else
  ## versioning defaults
  ## change these in $_SG_REVISION 
  _MAJOR='0.1'
  _MINOR='0'
  _SUFFIX='testing'
  echo -e "_MAJOR=$_MAJOR\n_MINOR=$_MINOR\n_SUFFIX=$_SUFFIX" > $_SG_REVISION
fi

let _MINOR++

_OPENWRT_REVISION="$_PWD/openwrt.revision"

## browser extension (if any)
_EXT_SRC="$_PWD/../../editor/build/superglue-firefox.xpi"

## include devTools?
_DEV_TOOLS=false

## get OpenWRT revision
_OPENWRT=$(fgrep -m1 'REVISION:=' $_IMAGEBUILDER/include/version.mk || echo 'r00000')
_OPENWRT=${_OPENWRT/REVISION:=/}
echo $_OPENWRT > $_OPENWRT_REVISION

_VERSION="$_MAJOR"."$_MINOR"-"$_SUFFIX"

## define how firmware files are named
_FN_PREFIX='superglue-firmware'

echo -e "Build ver: $_VERSION
Targets: $_TARGETS\n"

trap abort INT

abort() {
  echo -e "Bye..\n"
  exit 1
}

echo 'Ready? [Y/n] '; read _USER_ANSW
if [[ $_USER_ANSW == 'n' ]]; then
  abort
elif [[ $_USER_ANSW == 'y' || $_USER_ANSW == '' ]]; then
  true
fi

echo 'Removing temporary dirs (if any)'
find -maxdepth 1 -name *.tmp -exec rm -Rf {} \;

for _TARGET in $_TARGETS; do
  _BIN_DIR=$_BUILDS/$_VERSION/$_TARGET
  echo 'cleaning target and binary directories..'
  [[ -e $_TARGET.tmp ]] && rm -Rf $_TARGET.tmp 
  [[ -e $_BIN_DIR ]] && rm -Rf $_BIN_DIR
  sleep 1

  echo 'copying common and target specific files..'
  cp -Ra $_COMMON $_TARGET.tmp
  cp -Ra $_TARGET/* $_TARGET.tmp/
   sleep 1

  if [[ $_DEVTOOLS = false ]]; then
    echo 'removing devTools..'
    rm -Rf $_TARGET.tmp/opt/lib/devTools
  fi
  
  if [[ -e $_EXT_SRC ]]; then
    echo 'copying browser extension..'
    _EXT_DST="$_TARGET.tmp/opt/lib/extension"
    [[ -e $(dirname $_EXT_DST) ]] || mkdir $(dirname $_EXT_DST)
    cp -Ra $_EXT_SRC $_EXT_DST
    sleep 1
  fi

  echo 'cleaning temporary files..'
  find . -name '*.swp' -o -iname "[._]*.s[a-w][a-z]" -o -iname '*.tmp' -o -iname '*.bup' -o -iname '*.bak' -exec rm -Rf {} \;

  sed -e "s/%REVISION%/$_OPENWRT/g" -e "s/%VERSION%/$_VERSION/g" $_COMMON/etc/banner > $_TARGET.tmp/etc/banner

  echo $_VERSION > $_TARGET.tmp/etc/superglue_version
  cd $_IMAGEBUILDER && make clean

  echo -e "\nbuilding $_TARGET image!\n"
  sleep 2

  ## currently unused packages
  # kmod-fs-vfat kmod-fs-btrfs btrfs-progs kmod-fs-ext4 sudo 

  make image PROFILE=$_TARGET PACKAGES="bash gawk openssh-sftp-server haserl lighttpd lighttpd-mod-access lighttpd-mod-cgi lighttpd-mod-compress lighttpd-mod-accesslog lighttpd-mod-rewrite lighttpd-mod-auth lighttpd-mod-alias lighttpd-mod-proxy lighttpd-mod-setenv blkid block-mount mini-sendmail kmod-usb-storage kmod-scsi-generic mount-utils kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 kmod-nls-base coreutils-stat mini-httpd-htpasswd wireless-tools avahi-daemon kmod-fs-btrfs btrfs-progs swap-utils sfdisk coreutils-base64 coreutils-sha1sum rpcd-mod-iwinfo procps-ps uhttpd uhttpd-mod-ubus openvpn-openssl dtach curl" FILES=$_PWD/$_TARGET.tmp BIN_DIR=$_BIN_DIR/openwrt
  _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    echo -e "\nFAILED to build $_TARGET image :/ (are we missing packages?) \n"
    exit 1
  fi

  _FILENAME="$_FN_PREFIX"_"$_VERSION"_"$(echo $_TARGET | tr [:upper:] [:lower:])"

  cd $_BIN_DIR
  ln -s ./openwrt/openwrt-*-factory.bin ./$_FILENAME'_initial.bin' 
  ln -s ./openwrt/openwrt-*-sysupgrade.bin ./$_FILENAME'_upgrade.bin'
  [[ -e ./$_FILENAME'_initial.bin' ]] && [[ -e ./$_FILENAME'_upgrade.bin' ]] &&
  md5sum *.bin > md5sums
  _ERR=$?
  cd -

  if [[ $_ERR -eq 0 ]]; then 
    echo -e "\n$_TARGET build completed\n"
  else
    echo -e "\nError making symlinks! Images not built. Were they too large?\n"
    rm -Rf $_BIN_DIR
  fi

  echo 'Cleaning up..'
  make clean
  cd $_PWD 
  rm -Rf $_TARGET.tmp
  
done

if [[ $_ERR -eq 0 ]]; then
  ## if build succeeded bump revision
  echo -e "_MAJOR=$_MAJOR\n_MINOR=$_MINOR\n_SUFFIX=$_SUFFIX" > $_SG_REVISION
  echo -e "\n$_TARGET build SUCCEEDED! :)\n"

  ## create symlinks to the latest
  [[ -h $_BUILDS/latest ]] || rm -rf $_BUILDS/latest
  ln -sf $_BUILDS/$_VERSION -T $_BUILDS/latest
else
  echo -e "\n$_TARGET build FAILED.. :/\n"
  sleep 5
fi

exit $_ERR
