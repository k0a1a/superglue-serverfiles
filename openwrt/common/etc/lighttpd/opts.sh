#!/bin/sh

_CONFDIR='/etc/lighttpd'

for i in $*; do
  printf '%b' 'include ' "\"$_CONFDIR/$i\""
done

