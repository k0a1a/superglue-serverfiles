#!/bin/bash

## SuperGlue project | http://superglue.it | 2014 | GPLv3
## http://git.superglue.it/superglue/serverside/edit/master/common/rootFS/www/lib/post.sh
## author: Danja Vasiliev <danja@k0a1a.net>
##
## post.sh - all POST requests are redirected to this script.
## 
## examples:
## text:    curl --data-urlencode '<html><title>' http://host/file.html
## image:   curl --form "userimage=@file.png" -H "Expect:" http://host/file.png 
## command: curl --data-urlencode 'ls' http://host/cmd
##
## returns: 200 (+ output of operation) on success
##          406 (+ error message in debug mode) on error

## no globbing, for safety
set -o noglob

## some path variables
_WWW='/www'
_HTDOCS="${_WWW}/htdocs"
_TMP="${_HTDOCS}/tmp"
_LOG="${_HTDOCS}/logs/post.log"

## _DEBUG=0 no logging at all
## _DEBUG=1 writes to $_LOG file
## _DEBUG=2 adds [verbose].. to HTTP response. Can be triggered via 'Content-Type' header option
## eg: "Content-Type:application/octet-stream; verbose=1"
_DEBUG=1

#### FUNCTIONS

## logging
logThis() {
  [[ $_DEBUG -gt 0 ]] || return 0
  [[ $_ERR -gt 0 ]] && _TYPE='E:' || _TYPE='I:'  ## Info or Error indication
  local _TIME=$(printf '%(%d.%m.%Y %H:%M:%S)T' -1)
  printf '%b\n' "$_TIME  $_TYPE ${1} " >> $_LOG
  [[ $_DEBUG -gt 1 ]] && printf '%b\n' "[verbose] $_TYPE ${1}"
  return 0
}

## inject function execution trace to global _OUT
wTf() {
  local _WTF="$(printf '%s -> ' '| trace: '${FUNCNAME[*]:1})"
  _OUT="$_OUT $_WTF"
}

## urldecode
urlDecode() {
  local encoded="${1//+/ }"
  printf '%b' "${encoded//%/\x}"
}

## http response
headerPrint() {
  case ${1} in
    200) printf '%b' 'HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\n\n';;
    405) printf '%b' 'HTTP/1.1 405 Method Not Allowed\n\n';;
    406) printf '%b' 'HTTP/1.1 406 Not Acceptable\n\n';;
  esac
  return 0
}

## takes exit code variable $? and optional "message" string.
## exit code 0 simply falls through. when local message 
## is not provided tries to assign global $_OUT.
##
## eg: errorCheck $? "bad zombie"
##
## produces HTTP 406 header, $_OUT message, triggers logThis()
## and exits the main loop with exit >= 1.
errorCheck() {
  _ERR=${1}  ## exit code
  [[ $_ERR -gt 0 ]] || return 0
  local _MSG=${2}
  ## if $_OUT is present cut it down to one line
  ## otherwise assign message from the invokation arguments
  [[ $_OUT ]] && _OUT="${_OUT%%$'\n'*}" || { _OUT=${_MSG:='unknown error occured'}; wTf; }
  [[ -e $_POST_TMP ]] && rm -f $_POST_TMP
  headerPrint '406'
  logThis "${_OUT}";
  exit $_ERR
}

## get data from argv=data pair in POST request
## (any 4 character arg in the beginning of string is matched)
postGetData() {
  _POST="${_POST##????'='}"
}

## urlencoded POST dispatcher
postUrlenc() {
  ## decode stream
  _POST=$(urlDecode "$(< $_POST_TMP)")  ## decode global $_POST
  postGetData
  case "${_REQUEST_URI}" in
    \/cmd) postCmd  ;;  ## handle /cmd POST
        *) postHtml ;;  ## handle html POST
  esac
}

## handle /cmd POST
postCmd() {
  local _CMD=( ${_POST} )  ## convert POST to array
  [[ ${#_CMD[@]} -lt 5 ]] || errorCheck '1' "'${_CMD[*]}': too many arguments"
  local _EXE="${_CMD[0]}"  ## first member is command 
  local _ARG="${_CMD[@]:1}"  ## the rest is arguments
  ## note unquoted regex
  [[ ! "$_ARG" =~ (\.\.|^/| /) ]] || errorCheck '1' "'$_ARG': illegal path"

  ## 'ls' replacement function
  lss() {
    _D='\t' ## do we want a customizable delimiter? 
    while getopts 'la' _OPT; do
      case $_OPT in
        l) local _LNG="$_D%F$_D%s$_D%y$_D%U$_D%G$_D%a" ;;
        a) shopt -s dotglob
      esac
    done
    shift $((OPTIND-1)) ## removing used args
    [[ -z "${@}" ]] && _PT="./*"  ## list ./* if called with no args
    [[ -d "${@}" ]] && _PT="/*" ## add /* to directories
    ## if error occures return 0
    stat --printf "%n$_LNG\n" -- "${@%%/}"$_PT 2>/dev/null || _ERR=0
    return $_ERR
  }
  case "$_EXE" in
   ls|lss) _EXE="lss"; _ARG="${_ARG}" ;;  ## no error is returned
       cp) _ARG="${_ARG}" ;;
       rm) _ARG="${_ARG}" ;;  ## add recursive option if you need
       mv) _ARG="${_ARG}" ;;
    mkdir) _ARG="${_ARG}" ;;
      log) _EXE="tail"; _ARG="${_ARG} ${_LOG}" ;; 
     wget) _ARG="-q ${_ARG/ */} -O ${_ARG/* /}" ;;  ## quiet
        *) errorCheck '1' "'$_EXE': bad command" ;;
  esac
  ## toggle globbing  
  set +o noglob  
  _OUT=$($_EXE $_ARG 2>&1)
  _ERR=$?
   ## toggle globbing
  set -o noglob
  logThis "$_EXE $_ARG"
  errorCheck $_ERR
}

## handle html POST
postHtml() {
  ## save POST to file
  _OUT=$( (printf '%b' "${_POST}" > "${_HTDOCS}${_REQUEST_URI}") 2>&1)
  _ERR=$?
  errorCheck $_ERR
}

## octet POST dispatcher
postOctet() {
  ## get 'data:' header length 
  local IFS=','; read -d',' -r _DH < $_POST_TMP
  case "${_ENC}" in
    base64) postBase64Enc;;
    binary) postBinary ;;
         *) postGuessEnc ;;  ## handle data POST
  esac
}

## to be converted into a proper data-type detection function
postGuessEnc() {
  shopt -s nocasematch
  local _DTP="^.*\;([[:alnum:]].+)$" ## data-type header pattern
  ## look for encoding in the data header
  [[ "${_DH}" =~ ${_DTP} ]] && _ENC="${BASH_REMATCH[1]}"
  logThis "'$_ENC:' encoding is the best guess";
  shopt -u nocasematch
  case "$_ENC" in
                base64) postBase64Enc ;;
             ## binary) _ERR=1 ;; 
             ##   json) _ERR=1 ;;
   ## quoted-printable) _ERR=1 ;;
                     *) _ERR=1; _OUT="'${_ENC:='unknown'}' encoding, unknown POST failed";;
  esac
  errorCheck $_ERR
}

## handle base64 post
postBase64Enc() {
  logThis "'${_ENC}:' decoding stream"
  _DL=${#_DH}  ## get data-header length
  [[ $_DL -lt 10 ]] && { _DL=23; _SKP=0; } || { let _DL+=1; _SKP=1; }  ## '23' - what?!
  ## the line below seems to be the best solution for the time being
  ## dd 'ibs' and 'iflags' seem not to work on OpenWRT - investigate as it might be very useful
  _OUT=$( dd if=${_POST_TMP} bs=${_DL} skip=${_SKP} | base64 -d > "${_HTDOCS}${_REQUEST_URI}" 2>&1) 
  _ERR=$?
  errorCheck $_ERR
}

postBinary() {
  logThis "'binary': decoding stream"
  ## it is unclear what will be necessary to do here
  _OUT=$( dd if="${_POST_TMP}" of="${_HTDOCS}${_REQUEST_URI}" 2>&1 )
  _ERR=$?
  errorCheck $_ERR
}

postMpart() {
  logThis "'multipart': decoding stream"
  local _BND=$(findPostOpt 'boundary')
  ## bash is binary unsafe and eats away precious lines
  ## thus using gawk
  function cutFile() {
    gawk -v "want=$1" -v "bnd=$_BND" '
      BEGIN { RS="\r\n"; ORS="\r\n" }

      # reset based on boundaries
      $0 == "--"bnd""     { st=1; next; }
      $0 == "--"bnd"--"   { st=0; next; }
      $0 == "--"bnd"--\r" { st=0; next; }

      # search for wanted file
      st == 1 && $0 ~  "^Content-Disposition:.* name=\""want"\"" { st=2; next; }
      st == 1 && $0 == "" { st=9; next; }

      # wait for newline, then start printing
      st == 2 && $0 == "" { st=3; next; }
      st == 3 { print $0 }
      ' 2>&1
  }
  cutFile 'userimage' < "${_POST_TMP}" > "${_HTDOCS}${_REQUEST_URI}"
  _ERR=$?
  errorCheck $_ERR
}

## find arbitrary option supplied in Content-Type header
## eg: "Content-Type:application/octet-stream; verbose=1"
findPostOpt() {
  for i in "${CONTENT_TYPE[@]:1}"; do
    case "${i/=*}" in 
      "$1") printf '%b' "${i/*=}" ;;
    esac
  done
  return 0
}

## sanitize by backslashing all expandable symbols
escapeStr() {
  printf "%q" "${*}"
}

## brutally replace unwanted characters
cleanFname() {
  shopt -s extglob
  local _STR="${*}"
  echo -n "${_STR//[^[:alnum:]._\-\/\\]/_}"
  shopt -u extglob
}

#### MAIN LOOP

## timing
## TODO: remove it
## run once here and once at the end
read t z < /proc/uptime

## check if we are in $_HTDOCS directory
cd $_HTDOCS || errorCheck $? 'htdocs unavailable'
[[ ${PWD} == ${_HTDOCS} ]] || errorCheck $? 'htdocs misconfigured'
[[ $CONTENT_LENGTH -gt 0 ]] || errorCheck $? 'content length zero'

## URI is considered as a file dest to work with
## add 'index.html' to default and empty request uri
_REQUEST_URI="${REQUEST_URI/%\///index.html}"
_REQUEST_URI="$(urlDecode $_REQUEST_URI)"
_PATH="${_REQUEST_URI%/*}"

CONTENT_TYPE=( ${CONTENT_TYPE} )
_CONTENT_TYPE="${CONTENT_TYPE[0]/;}"
_ENC="${HTTP_CONTENT_ENCODING}"

#logThis "Len: $CONTENT_LENGTH Ctype: $CONTENT_TYPE Enc: $_CONTENT_ENCODING"

## check for 'verbose' option in POST
findPostOpt 'verbose' || { _DEBUG=2; logThis 'verbose mode is requested'; }

_POST_TMP=$(mktemp -p $_TMP)  ## make tmp POST file
cat > $_POST_TMP  ## cautiously storing entire POST in a file

## dispatching POST
case "${_CONTENT_TYPE}" in
  application\/x-www-form-urlencoded) postUrlenc ;;
           application\/octet-stream) postOctet ;;
                 multipart/form-data) postMpart ;;
                                   *) _ERR=1; _OUT='this is not a post' ;;
esac
[[ -e $_POST_TMP ]] && rm -f $_POST_TMP

## make sure we are good
errorCheck $_ERR 

[[ -z $_OUT ]] || _OUT="${_OUT}\n"

headerPrint '200' ## on success
printf '%b' "${_OUT}" 
logThis 'OK 200' 

read d z < /proc/uptime
logThis $((${d/./}-${t/./}))"/100s"

exit 0
