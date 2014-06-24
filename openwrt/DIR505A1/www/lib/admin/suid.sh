#!/bin/bash

SHELL=/bin/bash

if [[ $EUID -ne 0 ]]; then echo 'root only'; exit 1; fi

## parent process id
#_PPID=$PPID

## grandparent process id (process that called sudo that called us)
#_GPPID=$(ps -p$PPID -o ppid=)

## grandparent command
#_GPCMD=$(ps -f -p$_GPPID)

## check if called by admin.sh
#if [[ ! $_GPCMD =~ 'admin/admin.sh' ]]; then echo 'bad granny'; exit 1; fi

## get lighttpd session id
#_LSID=$(ps -C lighttpd -o sid=)

## parent session id
_PSID=${@: -1}

## our session id
#_SID=$(ps -p$$ -o sid=)

## check if we belong to group/session of lighty and admin.sh
#if [ $_LSID != $_PSID -o $_SID != $_LSID ]; then echo 'bad session'; exit 1; fi

## remove _PSID from the arguments
_ARGS=${@//$_PSID}

eval $_ARGS

exit $?
