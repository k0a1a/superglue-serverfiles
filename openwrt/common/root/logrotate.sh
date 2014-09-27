#!/bin/bash

_FILE=$1
_DATE=$(date +%s)

gzip -f $_FILE && 
mv $_FILE.gz $_FILE.$_DATE.gz




