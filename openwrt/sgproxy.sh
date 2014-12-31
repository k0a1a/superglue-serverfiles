#!/bin/bash

_SRV='usr.superglue.it'

while read x
  do echo "$x"
  done < <(ssh -N -T -R "$_SRV":0:localhost:80 sgproxy@"$_SRV" -p443  -o ExitOnForwardFailure=yes 2>&1)

  #ssh -N -T -R usr.superglue.it:0:localhost:80 sgproxy@usr.superglue.it -p443  -o ExitOnForwardFailure=yes #-y -y

