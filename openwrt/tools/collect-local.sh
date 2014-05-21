#!/bin/bash

## collect files across local fs

cp -f /etc/lighttpd/*.conf ./rootFS/etc/lighttpd/
cp -f /etc/lighttpd/.ht* ./rootFS/etc/lighttpd/

