#!/bin/bash

## SuperGlue project | http://superglue.it | 2014 | GPLv3
## http://git.superglue.it/superglue/serverfiles
##
## usb-part.sh - partition USB storage device

# - detect the last USB attached disk drive
# - check for sg-data partition

# - if sg-data not mounted but device is present, then
#   offer to format device

findUsbstor() {
  local _P='/sys/block/'
  local _D _DEV
  for _D in ${_P}sd*; do
    _DEV=$(readlink -f ${_D}/device)
    if [[ ${_DEV/usb} != $_DEV ]]; then
      _USBDEV="/dev/${_D/$_P}"
    fi
  done
  [[ $_USBDEV ]] || return 1
}

findMount() {
  local _M
  IFS=$'\n'
  for _M in $(mount); do 
    if [[ "$_M" != "${_M/"$_USBDEV"}" ]]; then 
      IFS=' ' _M=( $_M )
      _USBMNT="${_M[0]}"
    fi
  done
  [[ $_USBMNT ]] || return 1
}

usbPart() {

  ## partitions layout for sfdisk
  ## /dev/sdx1 64K, fat32
  ## TODO: define swap size according to ram
  ## /dev/sdx2 32M, swap v1 
  ## /dev/sdx3 rest of the disk, linux partition
  _PARTITIONS="unit: sectors

${_DEV}1 : start=     2048, size=      128, Id= b
${_DEV}2 : start=     4096, size=    65536, Id=82
${_DEV}3 : start=    69632, size=         , Id=83
${_DEV}4 : start=        0, size=        0, Id= 0
"

  ## base64 encoded gzip'ed image of /dev/sdx1 FAT32 partition
  _FAT_README='H4sICC5ykVQAA3NkYjEuZGQA7d3PaxNpGMDxp1VQI1FxYcWD+FRB8DJp68KCiFBxXAS1tUn8gSC8
7bxtZ5vMhJm3pgVxvSzsSezJi3+BePQmiAevPfof2FNFPHra7DtNo1VUSgWL7veTvDzv+z7zPplM
YCAE8q6cut+cncqDKeOkf3uf9Ev/XXnXJ6f9Q3bKqrty/N7DQ2+q9bFw/I8L9VD13EhtaFhV9xx+
duP24yPP3e4rT/Y83SFL+26uvB1+tfTr0sGVf2szca7+maROjU6kqTMTDatRnM8GqmMNa3KrcZLb
7KP8VCNttRbUJFG51Mpsnvvugs7aBXWpusxnpk2caBAEWi4JvkX90btO58PwbefLh+KnxOf//7bu
pu7v9i9uLYaLYTd288ttafnQ8fbKsc463cnlQDKxYiQSn2/6biBO5n0T38tlORw5ezG8M1S9OqYi
U+1u/SJuExkUGemtbvr1+frV3frjq+tVa9dqKpFdW/9yfjHcJf8U5/e+/jVff2gtX8StuZ4AAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAGzExOCV8xf19+C3YrDvw/zlAyKRSf40G6jRbrc39FqVpo1i
U1ktW3n/x0OVzJqoaQM37zbzBgBsUFlODA8NFr2jRwb0l/31rT4hAAAAAN+Ra/XJXz72r423r8W+
TyIAAAAAAPhxmUjk+l6Rv30rfv/vff9/7cdLvj3o5QAAAAAAwLdpz8STM8VW6XP5nGk0FlTquc10
Mk2cTVyRaKSTxtlI00SN5rZlMj/UMy47V1U/cLGL00R6O65X51o2m27MWY2M88e7NDPTVs6O6qXR
mtaroY6O68iFWjj+ubmBAf16oXKpVC5t6gyLheXSjHOtk5VK3isexI6N3AEAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwJb5D53OGNgAAAEA'

  if ! findUsbstor; then
    echo 'USB device not found'
    exit 1
  fi

  if findMount; then
    echo 'unmounting'
    umount -f $_USBMNT 2>&1
    if [[ $? -gt 0 ]]; then
      echo 'error unmounting'
      exit 1
    fi
  fi

  swapoff -a &>/dev/null
  sfdisk -D -f -q $_USBDEV <<< "$_PARTITIONS"

  if [[ $? -gt 0 ]]; then
    echo 'error making partitions'
    exit 1
  fi
  (echo -n "$_FAT_README" | base64 -d | gunzip -c > ${_USBDEV}1)
  if [[ $? -gt 0 ]]; then
    echo 'error cloning FAT readme partition'
    exit 1
  fi
  mkswap ${_USBDEV}2
  if [[ $? -gt 0 ]]; then
    echo 'error making swap'
    exit 1
  fi
  mkfs.btrfs -L sg-data ${_USBDEV}3
  if [[ $? -gt 0 ]]; then
    echo 'error making Btrfs'
    exit 1
  fi

}

