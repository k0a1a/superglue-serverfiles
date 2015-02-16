#!/bin/bash
## in ~/.ssh/config we have:
##  Host superglue
##  HostName 192.168.1.1
##  User root
##  StrictHostKeyChecking no
##  UserKnownHostsFile=/dev/null

scp ~/.ssh/id_rsa.pub superglue:/etc/dropbear/authorized_keys
