#!/bin/ash

## 'sg-data' partition should be already mounted here
_WWW='/www'

## check is /www in mounted 
## for as long as 30 seconds
n=0
while ! mountpoint -q $_WWW; do [ $n -gt 30 ] && exit 1;
  sleep 1
  let n++
done
unset n

_HTDOCS="$_WWW/htdocs"

## make ./htdocs if there is none
[ -e $_HTDOCS ] || mkdir $_HTDOCS
## if not writable chown with httpd
[ $(stat $_HTDOCS -c %U) == 'httpd' ] || chown -R httpd $_HTDOCS
[ ! $(stat $_HTDOCS -c %a) -lt '755' ] || chmod -R u+rwX $_HTDOCS

## check if index.html is present
[ -e $_HTDOCS/index.html ] || (
  cp /opt/lib/resources/default.html $_HTDOCS/default.html
  chown httpd $_HTDOCS/default.html 
  )

## check for log directory
[ -e $_WWW/log ] || (
  mkdir $_WWW/log
  chown httpd $_WWW/log
  )

## check for tmp directory
[ -e $_WWW/tmp ] || (
  mkdir $_WWW/tmp
  chown httpd $_WWW/tmp
  )

## reload Lighttpd since it might have had open files in /www
killall -HUP lighttpd

exit 0
