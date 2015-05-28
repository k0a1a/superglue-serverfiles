#!/bin/bash

_WWW="/www"
_SRC="${_WWW}/htdocs/demo.superglue.it/default-demo.html"
_HTDOCS="${_WWW}/htdocs-demo"

if ( [[ $REQUEST_URI != '/' ]] &&
[[ -e $_HTDOCS/$REQUEST_URI ]] ); then
  printf '%b' 'HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\n\n'
  cat $_HTDOCS/$REQUEST_URI
  exit 0
fi

## http response
headerPrint() {
  case ${1} in
    200) printf '%b' 'HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\n';;
    405) printf '%b' 'HTTP/1.1 405 Method Not Allowed\n';;
    406) printf '%b' 'HTTP/1.1 406 Not Acceptable\n';;
  esac
  return 0
}

setCookie() {
  printf '%b' 'Set-Cookie: ' "$1\n"
}

#_HASH=$(cat /dev/urandom | tr -dc 0-9 | head -c10)
## is this slow?
_HASH=($_HTDOCS/*)	## get all files
_HASH=${#_HASH[@]}	## count files

_PAGE="tryout-page-$_HASH"

## set cookie of we have none
if [[ -z $_PAGE ]]; then
  setCookie $_HASH
fi

## see if we have a file matching the cookie
if [[ -e $_HTDOCS/$_PAGE ]]; then
  printf '%b' "HTTP/1.1 301 Moved Permanently\nLocation: http://demo.superglue.it/$_PAGE\n\n"
  exit 0                                                                                 
fi  

## if neither URL or COOKIE is given then make a new demo page and direct user to it
cat $_SRC/default-demo.html > $_HTDOCS/$_PAGE
printf '%b' "HTTP/1.1 301 Moved Permanently\nLocation: http://demo.superglue.it/$_PAGE\n\n"
exit 0
