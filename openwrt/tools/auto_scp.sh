#!/bin/bash
## watch files recursively for changes 
## and scp to DEST
##
## assumes that DEST host has key based auth enabled,
## otherwise password will be prompted everytime

pwd

CMD='FILE=%f; DEST_FILE=${FILE#*/*/};
scp $FILE superglue:/$DEST_FILE; 
if [ $? -eq 0 ]; then 
  play -q -n synth 0.15 tri 5000.0 gain -25;
else
  play -q -n synth 0.5 tri 500.0 gain -10;
fi' 

#CMD='echo %f'

iwatch -c "eval $CMD" -e modify -r -X "\.sw.?|\.revision|\.tmp|tools" ./

