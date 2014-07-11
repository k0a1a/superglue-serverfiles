#!/bin/bash

_PWD=$(pwd)

_IMAGEBUILDER="$_PWD/../../../openwrt/OpenWrt-ImageBuilder-ar71xx_generic-for-linux-x86_64"
_BUILDS="$_PWD/../../../sg-builds"

## dirs with platform specific files
_TARGETS='DIR505A1 TLWR710'
#_TARGETS='DIR505A1'

## dir with common files
_COMMON='common'

_MAJOR='0.1'  ## bump that on major changes
_SUFFIX='git'  ## could be 'beta', 'rc', etc

## read build serial, incremented on every successful build
if [[ -e sg_$_MAJOR.revision ]]; then
  read _MINOR < sg_$_MAJOR.revision
  let _MINOR++
else _MINOR=0
fi

## get OpenWRT verison
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

  echo $_VERSION > $_TARGET.tmp/etc/superglue_version
  cd $_IMAGEBUILDER && make clean

  make image PROFILE=$_TARGET PACKAGES="bash gawk sudo procps-ps lighttpd lighttpd-mod-access lighttpd-mod-cgi lighttpd-mod-compress lighttpd-mod-accesslog lighttpd-mod-rewrite lighttpd-mod-auth lighttpd-mod-alias lighttpd-mod-setenv blkid kmod-fs-ext4 kmod-fs-vfat block-mount mini-sendmail kmod-usb-storage kmod-scsi-generic mount-utils kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 kmod-nls-base coreutils-stat mini-httpd-htpasswd" FILES=$_PWD/$_TARGET.tmp BIN_DIR=$_BUILDS/$_VERSION/$_TARGET/openwrt && 

  ln -s $_BUILDS/$_VERSION/$_TARGET/openwrt/openwrt-*-factory.bin $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-$_VERSION-$(echo $_TARGET | tr [:upper:] [:lower:])-factory.bin
  ln -s $_BUILDS/$_VERSION/$_TARGET/openwrt/openwrt-*-sysupgrade.bin $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-$_VERSION-$(echo $_TARGET | tr [:upper:] [:lower:])-sysupgrade.bin
  cd $_BUILDS/$_VERSION/$_TARGET
  md5sum *.bin > md5sums
  cd -

  if [[ $? -eq 0 ]]; then 
    echo -e "\n$_TARGET build completed\n"
  else
    _ERR=$?
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
  echo -e "\nSUCCESS\n"

  ## create symlinks to latest
  [[ -e $_BUILDS/latest ]] && touch $_BUILDS/latest || mkdir $_BUILDS/latest 
  for _TARGET in $_TARGETS; do
    [[ -e $_BUILDS/latest/$_TARGET ]] && rm -f $_BUILDS/latest/$_TARGET/* || mkdir $_BUILDS/latest/$_TARGET

    ln -sf $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-*-factory.bin $_BUILDS/latest/$_TARGET/superglue-firmware-latest-$(echo $_TARGET | tr [:upper:] [:lower:])-factory.bin
    ln -sf $_BUILDS/$_VERSION/$_TARGET/superglue-firmware-*-sysupgrade.bin $_BUILDS/latest/$_TARGET/superglue-firmware-latest-$(echo $_TARGET | tr [:upper:] [:lower:])-sysupgrade.bin
  done

else
  echo -e "\nFAILED\n"
fi

exit $_ERR
 
