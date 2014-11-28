#!/bin/bash
## watch files recursively for changes 
## and scp to DEST
##
## assumes that DEST host has key based auth enabled,
## otherwise password will be prompted everytime

CMD='FILE=%f; DEST_FILE=${FILE#*/*/};
scp $FILE superglue:/$DEST_FILE; 
if [ $? -eq 0 ]; then 
  play -q -n synth 0.1 tri 5000.0 gain -15;
else
  play -q -n synth 0.1 tri 1000.0 gain -10;
fi' 

#CMD='echo %f'

iwatch -c "eval $CMD" -e modify -X '\.sw.?' -r .

