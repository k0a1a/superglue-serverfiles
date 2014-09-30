#!/bin/bash

## Firmware image building script
## http://superglue.it | Danja Vasiliev, 2014
##
## Needs:
## - OpenWRT ImageBuilder blob:
##    http://downloads.openwrt.org/barrier_breaker/14.07-rc3/ar71xx/generic 
##    or http://downloads.openwrt.org/snapshots/trunk/ar71xx
## - Superglue serverfiles local repo (which this script is part of):
##    http://git.superglue.it/superglue/serverfiles/tree/master

_PWD=$(pwd)
_IMAGEBUILDER="$_PWD/../../../openwrt/OpenWrt-ImageBuilder-ar71xx_generic-for-linux-x86_64"
_BUILDS="$_PWD/../../../sg-builds"

[[ -e $_IMAGEBUILDER ]] || (echo 'ImageBuilder is missing'; exit 1;)
[[ -e $_BUILDS ]] || (echo 'Builds directory is missing'; exit 1;)

## dirs with platform specific files
_TARGETS='DIR505A1 TLWR710 WRT160NL'
#_TARGETS='DIR505A1'

## dir with common files
_COMMON='common'

_MAJOR='0.1'  ## bump that on major changes
#_SUFFIX='git'  ## could be 'beta', 'rc', etc
_SUFFIX='testing'  ## could be 'beta', 'rc', etc

## read build serial, incremented on every successful build
if [[ -e sg_$_MAJOR.revision ]]; then
  read _MINOR < sg_$_MAJOR.revision
  let _MINOR++
else _MINOR=0
fi

## get OpenWRT revision number
_OPENWRT=$(fgrep -m1 'REVISION:=' $_IMAGEBUILDER/include/version.mk || echo 'r00000')
_OPENWRT=${_OPENWRT/REVISION:=/}
echo $_OPENWRT > openwrt.revision

_VERSION="$_MAJOR"."$_MINOR"-"$_SUFFIX"

echo "About to start building version: $_VERSION"
echo -e "Targets for this build: $_TARGETS\n"

echo 'Removing temporary dirs (if any)'
find -maxdepth 1 -name *.tmp -exec rm -Rf {} \;

for _TARGET in $_TARGETS; do
  [[ -e $_TARGET.tmp ]] && rm -Rf $_TARGET.tmp 
  cp -Ra $_COMMON $_TARGET.tmp
  cp -Ra $_TARGET/* $_TARGET.tmp/

  sed -e "s/%REVISION%/$_OPENWRT/g" -e "s/%VERSION%/$_VERSION/g" $_COMMON/etc/banner > $_TARGET.tmp/etc/banner

  echo $_VERSION > $_TARGET.tmp/etc/superglue_version
  cd $_IMAGEBUILDER && make clean

  make image PROFILE=$_TARGET PACKAGES="bash gawk sudo procps-ps haserl lighttpd lighttpd-mod-access lighttpd-mod-cgi lighttpd-mod-compress lighttpd-mod-accesslog lighttpd-mod-rewrite lighttpd-mod-auth lighttpd-mod-alias lighttpd-mod-setenv blkid kmod-fs-ext4 kmod-fs-vfat kmod-fs-btrfs btrfs-progs block-mount mini-sendmail kmod-usb-storage kmod-scsi-generic mount-utils kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 kmod-nls-base coreutils-stat mini-httpd-htpasswd" FILES=$_PWD/$_TARGET.tmp BIN_DIR=$_BUILDS/$_VERSION/$_TARGET/openwrt && 

  ln -s $_BUILDS/$_VERSION/$_TARGET/openwrt/openwrt-*-factory.bin $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-$_VERSION-$(echo $_TARGET | tr [:upper:] [:lower:])-factory.bin
  ln -s $_BUILDS/$_VERSION/$_TARGET/openwrt/openwrt-*-sysupgrade.bin $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-$_VERSION-$(echo $_TARGET | tr [:upper:] [:lower:])-sysupgrade.bin
  cd $_BUILDS/$_VERSION/$_TARGET
  md5sum *.bin > md5sums
  cd -

  _ERR=$?

  if [[ $_ERR -eq 0 ]]; then 
    echo -e "\n$_TARGET build completed\n"
  else
    rm -Rf $_BUILDS/$_VERSION/$_TARGET
  fi

  echo 'Cleaning up..'
  make clean
  cd $_PWD 
  rm -Rf $_TARGET.tmp
  
done

if [[ $_ERR -eq 0 ]]; then
  ## if build succeeded bump revision
  echo $_MINOR > sg_$_MAJOR.revision
  echo -e "\nBuilding SUCCEEDED! :)\n"

  ## create symlinks to latest
  [[ -e $_BUILDS/latest ]] && touch $_BUILDS/latest || mkdir $_BUILDS/latest 
  for _TARGET in $_TARGETS; do
    [[ -e $_BUILDS/latest/$_TARGET ]] && rm -f $_BUILDS/latest/$_TARGET/* || mkdir $_BUILDS/latest/$_TARGET

    ln -sf $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-*-factory.bin $_BUILDS/latest/$_TARGET/superglue-firmware-latest-$(echo $_TARGET | tr [:upper:] [:lower:])-factory.bin
    ln -sf $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-*-sysupgrade.bin $_BUILDS/latest/$_TARGET/superglue-firmware-latest-$(echo $_TARGET | tr [:upper:] [:lower:])-sysupgrade.bin
  done

else
  echo -e "\nBuilding FAILED.. :/\n"
fi

exit $_ERR
