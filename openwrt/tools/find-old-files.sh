#!/bin/bash

## Find files older than given age.
## Replacement for busybox find lacking mtime argument.
## This script doesn't traverse directories.
## danja@k0a1a.net | Superglue project | 2016

set -e 

DIR=$1
MAXAGEDAYS=$2

[ ! -z $DIR ] || (echo "usage: $(basename $0) <dir> <days>"; exit 1;)
[ -d $DIR ] || (echo $DIR' dir does not exist'; exit 1;)
[ ! -z $MAXAGEDAYS ] && [ -z "${MAXAGEDAYS##[0-9]*}" ] || (echo 'second parameter must be number of days'; exit 1;)

MAXAGE=$(($(date +%s)-86400*${MAXAGEDAYS}))

for FILE in $DIR/*; do
    if [[ $(date -r $FILE +%s) -le $MAXAGE ]]; then
        echo $FILE
    fi
done
   

