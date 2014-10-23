#!/usr/bin/haserl --shell=/bin/bash --upload-limit=32768 --upload-dir=/tmp
<%# upload limit: 32Mb %>
<%

#some path variables
_WWW='/www'
_TMP="${_WWW}/tmp"
_LOG="${_WWW}/log/upload.log"
_DEBUG=1

err() {
  _ERR="$?"
  [[ "$_ERR" -gt 0 ]] || return 0
  log "$1"
  head "${2:='400'}"
  exit "$_ERR"
} 

log() {
  [[ "$_DEBUG" -gt 0 ]] || return 0
  local _TYPE='I:'
  [[ "$_ERR" -gt 0 ]] && _TYPE='E:'
  local _TIME; printf -v _TIME '%(%d.%m.%Y %H:%M:%S)T' -1
  printf '%b\n' "$_TIME  $_TYPE ${@} " >> "$_LOG"
  [[ "$_DEBUG" -gt 1 ]] && printf '%b\n' "[verbose] $_TYPE ${1}"
  return 0
}

head() {
  case "$1" in
 200|'') printf '%b' 'HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\n\n';;
    405) printf '%b' 'HTTP/1.1 405 Method Not Allowed\n\n';;
    406) printf '%b' 'HTTP/1.1 406 Not Acceptable\n\n';;
      *) printf '%b' 'HTTP/1.1 400 Bad Request\n\n';;
  esac
}

#_REF="$HTTP_REFERER"
#_SESS="$SESSIONID"
#log $_REF $_SESS


## checks and sanitation
[[ ${CONTENT_TYPE^^} == MULTIPART/FORM-DATA* ]] || err 'wrong content type' '406' 
[[ "${REQUEST_METHOD^^}" == "POST" ]] || err 'wrong method, not a post' '405'
_UPLD="${HASERL_fwupload_path##*/}"
mv "$_TMP/$_UPLD" "$_TMP/fwupload.bin" 2>/dev/null || err 'error renaming upload'

log 'upload OK'
head '200'

#UPLD="${HASERL_fwupload_path##*/}"
#UPLD="${_UPLD//[^a-zA-Z0-9_.-]/}"
#[ -n "$_UPLD" ] || err 'empty filename value, sanitation failed?'
#[ -f "$_TMP/$_UPLD" ] || err 'can not access uploaded file, sanitation failed?'
#log "$_UPLD"

%>


