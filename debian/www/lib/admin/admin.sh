#!/bin/bash

_PWDFILE='/www/lib/admin/htpasswd'

_TMP='/tmp'
_LOG="${_TMP}/admin.log"

_DEBUG=1

## logging
logThis() {
  [[ $_DEBUG -gt 0 ]] || return 0
  [[ $_ERR -gt 0 ]] && _TYPE='E:' || _TYPE='I:'  ## Info or Error indication
  local _TIME=$(printf '%(%d.%m.%Y %H:%M:%S)T' -1)
  printf '%b\n' "$_TIME  $_TYPE ${1} " >> $_LOG
  [[ $_DEBUG -gt 1 ]] && printf '%b\n' "[verbose] $_TYPE ${1}"
  return 0
}

## http response
headerPrint() {
  case ${1} in
    200) printf '%b' 'HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\n\n';;
    301) printf '%b' "HTTP/1.1 301 Moved Permanently\nLocation: ${HTTP_REFERER}\n\n";;
    403) printf '%b' 'HTTP/1.1 403 Forbidden\n\n';;
    405) printf '%b' 'HTTP/1.1 405 Method Not Allowed\n\n';;
    406) printf '%b' 'HTTP/1.1 406 Not Acceptable\n\n';;
  esac
  return 0
}

htDigest() {
  _USER='admin'
  _PWD=$1
  _REALM='superglue'
  _HASH=$(echo -n "$_USER:$_REALM:$_PWD" | md5sum | cut -b -32)
  echo -n "$_USER:$_REALM:$_HASH"
}

urlDec() {
  local value=${*//+/%20}
  for part in ${value//%/ \\x}; do
    printf "%b%s" "${part:0:4}" "${part:4}"
  done
}

setQueryVars() {
  local _POST=$(cat)
  local vars=${_POST//\*/%2A}
  for var in ${vars//&/ }; do
    local value=$(urlDec "${var#*=}")
    value=${value//\\/\\\\}
    eval "_${var%=*}=\"${value//\"/\\\"}\""
  done
}

getQueryFile() {
  _POST_TMP=$(mktemp -p $_TMP)  ## make tmp POST file
  cat > $_POST_TMP  ## cautiously storing entire POST in a file
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
  cutFile 'fwupload' < "${_POST_TMP}" > "${_TMP}/fwupload.bin"
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

runSuid() {
  local _SID=$(ps -p $$ -o sid=)  ## pass session id to the child
  local _CMD=$@
  sudo ./suid.sh $_CMD $_SID 2>&1
}

pwdChange() {
  if [[ ! -z "${_pwd##$_pwdd}" ]]; then 
    _ERR=1
    showMesg 'Passwords did not match'
  fi

  if [[ ${#_pwd} -lt 6 ]]; then
    _ERR=1
    showMesg 'Password must be at least 6 characters long'
  fi

  runSuid "echo -e \"$_pwd\n$_pwd\" | passwd root"
  runSuid "echo $(htDigest $_pwd) > $_PWDFILE"
  _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Password change failed'
  else
    showMesg 'Password is changed'
  fi

}

ssidChange() {
  ## default enc for now
  local _enc='psk2'
  logThis "new ssid is: $_ssid"
  logThis "new key is: $_key"

  if [[ $_ssid != $_pssid ]]; then
    if [[ ${#_ssid} -lt 4 ]]; then
     _ERR=1
     showMesg 'SSID must be at least 4 characters long'
    fi
    setUci ssid $_ssid
    _ERR=$?
    [[ $_ERR -gt 0 ]] && showMesg 'New SSID is not set'
  fi

  if [[ $_key != $_pkey ]]; then 
    if [[ -z $_key ]]; then
      ## if key is empty set encryption to none and remove key
      setUci key && setUci enc 'none'
      _ERR=$?
    else
      if [[ ${#_key} -lt 8 ]]; then
       _ERR=1
        showMesg 'Passphrase must be at least 8 characters long'
      fi
      setUci key $_key && setUci enc $_enc
      _ERR=$?
      [[ $_ERR -gt 0 ]] && showMesg 'Passphrase is not set'
    fi
  fi

  [[ $_ERR -gt 0 ]] && showMesg 'Wireless changes failed'
  commitUci && showMesg 'Wireless changes applied'
}

#showError() {
#  headerPrint 406
#  logThis "$@"
#  echo "ERROR: $@"
#  exit 1
#}

showMesg() {
  logThis "$@"
  local _MSG=$1
  local _SUBMSG=$2
  _MSG=${_MSG:='Not defined'}
  _SUBMSG=${_SUBMSG:='back to control panel in a second..'}
  if [[ $_ERR -gt 0 ]]; then
    local _TYPE='ERROR: '
    headerPrint 406
  else
    local _TYPE='OK: '
    headerPrint 200
  fi
  htmlHead "<meta http-equiv='refresh' content='5;url=${HTTP_REFERER}'>"
  echo "<body>
<img src='/resources/default/img/placeholder.png' class='logo'>
<hr>
<h2 style='display:inline'>$_TYPE $_MSG</h2>
<span style='display:inline; margin-left: 50px;'>$_SUBMSG</span>"
  if [[ $_ERR -eq 0 ]]; then
    echo "<form action=${HTTP_REFERER} method='get'><input type='submit' value='Back'></form>"
  fi

echo "<hr>
</body></html>"
  exit 0
}

updateFw() {
  logThis "updating fw"
  _FWFILE="${_TMP}/fwupload.bin"
  logThis "fwfile is: $(ls -lad $_FWFILE)"
  _OUT="$(/sbin/sysupgrade -T $_FWFILE 2>&1)"
  _ERR=$?
  [[ $_ERR -gt 0 ]] && showMesg "$_OUT"
  _OUT="$(runSuid /sbin/mtd -q write $_FWFILE firmware)"
  _ERR=$?
  [[ $_ERR -gt 0 ]] && showMesg "mtd failed, $_OUT"
  showMesg 'Firmware update is completed, rebooting..' 'this might take up to 60 seconds'
  runSuid reboot
}

rebootNow() {
  logThis "reboot: now!"
  showMesg 'Rebooting..' 'this might take up to 60 seconds'
  runSuid reboot
}

getUci() {
  local _ARG=''
  case $1 in
    ssid) _ARG='wireless.@wifi-iface[0].ssid';;
    enc) _ARG='wireless.@wifi-iface[0].encryption';;
    key) _ARG='wireless.@wifi-iface[0].key';;
    *) logThis 'bad uci command'; headerPrint 405; echo 'no such uci command'; exit 1;;
  esac

  if [ ! -z $_ARG ]; then
    /sbin/uci get $_ARG
  fi
}

setUci() {
  local _ARG=''
  case $1 in
    ssid) _ARG='wireless.@wifi-iface[0].ssid';;
    enc) _ARG='wireless.@wifi-iface[0].encryption';;
    key) _ARG='wireless.@wifi-iface[0].key';;
   *) logThis 'bad uci command'; headerPrint 405; echo 'no such uci command'; exit 1;;
  esac

  if [ -z $2 ]; then
    logThis "empty $_ARG value, removing record"
    runSuid /sbin/uci delete $_ARG || ( echo "uci delete $_ARG: error"; exit 1; )
  fi

  if [ ! -z $_ARG ]; then
    logThis "setting $_ARG value"
    runSuid /sbin/uci set $_ARG=$2 || ( echo "uci set $_ARG: error"; exit 1; )
  fi
}

commitUci() {
  runSuid /sbin/uci commit || echo "uci commit $_ARG: error"
  runSuid /sbin/wifi || echo 'wifi: error'
}

htmlHead() {
echo "<!doctype html>
<html>
<head><title>SuperGlue | Administration</title>
$@
<script type='text/javascript' src='/resources/default/js/jquery.js'></script>
<style> 
body { background:#ccc; color:#000; margin: 20px 0 0 200px; font-family: TitilliumWeb;}
input { display: block; }
.inline { display: inline; }
img.logo { position: absolute; left:50px; top: 20px;}
pre { white-space: pre-wrap; }
@font-face { font-family: TitilliumWeb; src: url('/resources/default/fonts/Titillium_Web/TitilliumWeb-Regular.ttf') format('truetype'); }
@font-face { font-family: TitilliumWeb; font-weight: bold; src: url('/resources/default/fonts/Titillium_Web/TitilliumWeb-Bold.ttf') format('truetype'); }
</style>
</head>"
}

## unless auth is disabled in lighttpd
## it should never come to this, 
if [[ -z $HTTP_AUTHORIZATION ]]; then
  logThis 'no auth'
  headerPrint 403
  echo 'no is no'
  exit 1
else logThis 'auth OK'
fi

if [[ $REQUEST_METHOD == 'POST' ]]; then
  if [[ $CONTENT_LENGTH -gt 0 ]]; then
    CONTENT_TYPE=( ${CONTENT_TYPE} )
    _CONTENT_TYPE="${CONTENT_TYPE[0]/;}"
    _ENC="${HTTP_CONTENT_ENCODING}"
    logThis $REQUEST_URI
    logThis $CONTENT_TYPE
    case "${_CONTENT_TYPE}" in
      application/x-www-form-urlencoded) setQueryVars;;
      multipart/form-data) getQueryFile;;
      *) _ERR=1; _OUT='this is not a post' ;;
    esac

    case $REQUEST_URI in
      /admin/pwdchange) pwdChange;;
      /admin/ssidchange) ssidChange;;
      /admin/updatefw) updateFw;;
      /admin/rebootnow) rebootNow;;
      *) logThis 'bad action'; headerPrint 405; echo 'no such thing'; exit 1;;
    esac
  fi
  headerPrint 301
fi



headerPrint 200
## html head
htmlHead
echo "<body>
<img src='/resources/default/img/placeholder.png' class='logo'>
<hr>
<h2 style='display:inline'>Superglue server control panel</h2>
<span style='display:inline; margin-left: 50px;'>$(uptime)</span>
<hr>

Change password:
<form method='post' action='/admin/pwdchange'>
<input type='text' name='usr' value='admin' readonly>
<input type='password' name='pwd'>
<input type='password' name='pwdd'>
<input type='submit' value='Apply'>
</form>
<hr>

Configure wireless network:
<form method='post' action='/admin/ssidchange'>
<input type='text' name='ssid' value='$(getUci ssid)'>
<input type='text' name='key' value='$(getUci key)'>
<input type='hidden' name='pssid' value='$(getUci ssid)'>
<input type='hidden' name='pkey' value='$(getUci key)'>
<input type='submit' value='Apply'>
</form>

<hr>

Update firmware:
<form method='post' action='/admin/updatefw' enctype='multipart/form-data'>
<input type='file' name='fwupload'>
<input type='submit' id='upload' value='Upload'>
</form>

<hr>

<form action='/admin/rebootnow' method='post' class='inline'>
<input type='hidden' name='reboot' value='now' class='inline'>
<input type='submit' value='Reboot' class='inline'>
</form>

<form action='http://logout@${HTTP_HOST}/admin' method='get' class='inline'>
<input type='submit' value='Logout' class='inline'>
</form>

<hr>

$_POST

Environment:
<pre>$(env)</pre>
Memory:
<pre>$(free)</pre>
Storage:
<pre>$(df -h)</pre>

</body></html>"

exit 0
