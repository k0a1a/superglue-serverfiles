#!/bin/bash

## Firmware image building script
## http://superglue.it | Danja Vasiliev, 2014
##
## Needs:
## - OpenWRT ImageBuilder blob:
##    http://downloads.openwrt.org/barrier_breaker/14.07/ar71xx/generic
##    or http://downloads.openwrt.org/snapshots/trunk/ar71xx
## - Fetch (needed) packages:
##    https://downloads.openwrt.org/barrier_breaker/14.07/ar71xx/generic/packages
## - Superglue serverfiles local repo (which this script is part of):
##    http://git.superglue.it/superglue/serverfiles/tree/master

set -e

## make sure we are running from upper level directory
[[ $(pwd) == $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ]] && (echo "ERROR: must be run as ./tools/$(basename $0), exiting"; exit 1;)

_PWD=$(pwd)
_IMAGEBUILDER="$_PWD/../../../openwrt/OpenWrt-ImageBuilder-ar71xx_generic-for-linux-x86_64"
_BUILDS="$_PWD/../../../sg-builds"

[[ -e $_IMAGEBUILDER ]] || (echo 'ImageBuilder is missing'; exit 1;)
[[ -e $_BUILDS ]] || (echo 'Builds directory is missing'; exit 1;)

set +e

## dirs with platform specific files
#_TARGETS='DIR505A1 TLWR710 WRT160NL'
_TARGETS='TLWR710'

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

#_SG_REVISION="$_PWD/superglue.revision"
_OPENWRT_REVISION="$_PWD/openwrt.revision"

## browser extension (if any)
_EXT_SRC="$_PWD/../../editor/build/firefox/superglue.xpi"

## read build serial, incremented on every successful build
#if [[ -e $_SG_REVISION ]]; then
#  read _MINOR < $_SG_REVISION
#  let _MINOR++
#else _MINOR=0
#fi

## get OpenWRT revision number
_OPENWRT=$(fgrep -m1 'REVISION:=' $_IMAGEBUILDER/include/version.mk || echo 'r00000')
_OPENWRT=${_OPENWRT/REVISION:=/}
echo $_OPENWRT > $_OPENWRT_REVISION

_VERSION="$_MAJOR"."$_MINOR"-"$_SUFFIX"

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

  if [[ -e $_EXT_SRC ]]; then
    echo 'copying browser extension..'
    _EXT_DST="$_TARGET.tmp/opt/lib/extension/superglue.xpi"
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

  ## package stash, might need these:
  # kmod-fs-vfat kmod-fs-btrfs btrfs-progs

  make image PROFILE=$_TARGET PACKAGES="bash gawk sudo procps-ps openssh-sftp-server haserl lighttpd lighttpd-mod-access lighttpd-mod-cgi lighttpd-mod-compress lighttpd-mod-accesslog lighttpd-mod-rewrite lighttpd-mod-auth lighttpd-mod-alias lighttpd-mod-setenv blkid kmod-fs-ext4 block-mount mini-sendmail kmod-usb-storage kmod-scsi-generic mount-utils kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 kmod-nls-base coreutils-stat mini-httpd-htpasswd wireless-tools avahi-daemon kmod-fs-btrfs btrfs-progs swap-utils sfdisk coreutils-base64 rpcd-mod-iwinfo dtach" FILES=$_PWD/$_TARGET.tmp BIN_DIR=$_BIN_DIR/openwrt
  _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    echo -e "\nFAILED to build $_TARGET image :/ (are we missing packages?) \n"
    exit 1
  fi

  ## define how firmware files are named
  _FN_PREFIX='superglue-firmware'
  _FILENAME="$_FN_PREFIX"_"$_VERSION"_"$(echo $_TARGET | tr [:upper:] [:lower:])"

  ln -s $_BIN_DIR/openwrt/openwrt-*-factory.bin $_BIN_DIR/$_FILENAME'_initial.bin' &&
  ln -s $_BIN_DIR/openwrt/openwrt-*-sysupgrade.bin $_BIN_DIR/$_FILENAME'_upgrade.bin' &&
  cd $_BIN_DIR &&
  md5sum *.bin > md5sums
  cd -

  _ERR=$?
  if [[ $_ERR -eq 0 ]]; then 
    echo -e "\n$_TARGET build completed\n"
  else
    rm -Rf $_BIN_DIR
  fi

  echo 'Cleaning up..'
  make clean
  cd $_PWD 
  rm -Rf $_TARGET.tmp
  
done

if [[ $_ERR -eq 0 ]]; then
  ## if build succeeded bump revision
  ## echo $_MINOR > $_SG_REVISION
  echo -e "_MAJOR=$_MAJOR\n_MINOR=$_MINOR\n_SUFFIX=$_SUFFIX" > $_SG_REVISION
  echo -e "\nBuilding SUCCEEDED! :)\n"

  ## create symlinks to latest
  [[ -e $_BUILDS/latest ]] && touch $_BUILDS/latest || mkdir $_BUILDS/latest 
  for _TARGET in $_TARGETS; do
    [[ -e $_BUILDS/latest/$_TARGET ]] && rm -f $_BUILDS/latest/$_TARGET/* || mkdir $_BUILDS/latest/$_TARGET
    #set -o xtrace
    _FACTORY="$_BUILDS"/latest/"$_TARGET"/$_FILENAME'_initial.bin'
    _SYSUPGRADE=$_BUILDS/latest/"$_TARGET"/$_FILENAME'_upgrade.bin'

    ln -sf $_BIN_DIR/$_FILENAME'_initial.bin' $_FACTORY &&
      echo -e "$_FACTORY\n"
    ln -sf $_BIN_DIR/$_FILENAME'_upgrade.bin' $_SYSUPGRADE &&
      echo -e "$_SYSUPGRADE\n"

    # set +o xtrace
  done

else
  echo -e "\nBuilding FAILED.. :/\n"
fi

exit $_ERR
