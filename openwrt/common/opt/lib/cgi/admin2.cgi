#!/usr/bin/haserl --shell=/bin/bash  --upload-limit=32768 --upload-dir=/www/tmp 
<%# upload limit: 32Mb %>
<%

_WWW='/www'
_PWDFILE="/opt/lib/htpasswd"
_TMP="${_WWW}/tmp"
_LOG="${_WWW}/log/admin.log"
_DEBUG=1

err() {
  _ERR="$?"
  [[ "$_ERR" -gt 0 ]] || return 0
  log "$1"
  head "${2:='400'}"
  exit "$_ERR"
} 

logThis() {
  [[ "$_DEBUG" -gt 0 ]] || return 0
  local _TYPE='I:'
  [[ "$_ERR" -gt 0 ]] && _TYPE='E:'
  local _TIME; printf -v _TIME '%(%d.%m.%Y %H:%M:%S)T' -1
  printf '%b\n' "$_TIME  $_TYPE ${@} " >> "$_LOG"
  [[ "$_DEBUG" -gt 1 ]] && printf '%b\n' "[verbose] $_TYPE ${1}"
}

headerPrint() {
  case "$1" in
 200|'') printf '%b' 'HTTP/1.1 200 OK\r\n';;
    301) printf '%b' "HTTP/1.1 301 Moved Permanently\r\nLocation: $HTTP_REFERER\r\n";;
    403) printf '%b' 'HTTP/1.1 403 Forbidden\r\n';;
    405) printf '%b' 'HTTP/1.1 405 Method Not Allowed\r\n';;
    406) printf '%b' 'HTTP/1.1 406 Not Acceptable\r\n';;
      *) printf '%b' 'HTTP/1.1 400 Bad Request\r\n';;
  esac
  printf '%b' 'Content-Type: text/html\r\n\r\n';
}

htDigest() {
  _USER='admin'
  _PWD=$1
  _REALM='superglue'
  _HASH=$(echo -n "$_USER:$_REALM:$_PWD" | md5sum | cut -b -32)
  echo -n "$_USER:$_REALM:$_HASH"
}

setQueryVars() {
  env
}

getQueryFile() {
  local _UPLD="${HASERL_fwupload_path##*/}"
  logThis "'multipart': decoding stream"
  mv "$_TMP/$_UPLD" "$_TMP/fwupload.bin" 2>/dev/null || _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Firmware upload has failed' 'Reboot your Superglue server and try again'
  fi
}

validIp() {
  local _IP=$1
  local _RET=1
  if [[ $_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    _IP=($_IP)
    IFS=$OIFS
    [[ ${_IP[0]} -le 255 && ${_IP[1]} -le 255 && ${_IP[2]} -le 255 && ${_IP[3]} -le 255 ]]
    _RET=$?
  fi
  return $_RET
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

lanAddr() {
  logThis "new LAN addr is: $_laddr"
  validIp $_laddr || showMesg 'Not valid network address'
  doUci set laddr $_laddr
  _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Setting network address failed'
  else
    (sleep 1; doUci commit network; doUci commit wireless;)&
    showMesg 'New network address is set' "Your server is now accessible under <a href='http://superglue.local/admin'>http://superglue.local/admin</a>"
  fi 
}

wanSet() {
  if [[ ! -z $_wanifname ]]; then
    ## eth and wlan wan cases are different!
    ## eth wan requires:
    ##   config interface 'wan'
    ##     option ifname 'eth0'
    ##
    ##   config wifi-iface
    ##     option device 'radio0'
    ##     option network 'wan'     
    ##     option disabled '1' (or no 'config wifi-iface' section at all)
    ##
    ## wlan wan requires:
    ##   config interface 'wan'
    ##     option proto 'dhcp'
    ##     (without 'option ifname' specified!)
    ##
    ##    config wifi-iface 
    ##      option device 'radio0'
    ##      option network 'wan'
    logThis "wan.ifname=$_wanifname"
    if [[ $_wanifname == 'eth0' ]]; then
      doUci set wanifname $_wanifname
      doUci set wanwifacedis '1'
    elif [[ $_wanifname == 'wlan1' ]]; then
      doUci set wanifname ''
      doUci set wanwifacedis ''
    fi
    if [[ $_wanproto == 'dhcp' ]]; then
      doUci set wanproto dhcp
    elif [[ $_wanproto == 'static' ]]; then
      logThis "wan.ipaddr=$_wanipaddr"
      doUci set wanproto static
      doUci set wanipaddr $_wanipaddr
      doUci set wannetmask $_wannetmask
    fi
    if [[ $_wanifname == 'wlan1' ]]; then
      ssidChange || showMesg 'Wireless changes failed'
    fi
    ## background the following
    doUci commit network &&
    showMesg 'Internet connection is configured' 'Waiting for device to get ready' ||
    showMesg 'Configuring Internet connection failed'
  fi
  logThis "new WAN iface is: $_wanifname"
}

ssidChange() {
  ## check for iface
  [[ ! $_iface =~ ^('wan'|'lan')$ ]] && showMesg 'Error changing wireless settings' 'unknown/unconfigured interface'
  logThis "$_iface is being set"

  _p=$_iface

  ## default enc for now
  local _enc='psk2'
  if [[ $_iface == 'wan' ]]; then
    local _mode='sta'
    local _ssid="${_wanssid}"
    local _key="${_wankey}"
  else 
    local _mode='ap'
    local _ssid="${_lanssid}"
    local _key="${_lankey}"
  fi

  logThis "ssid: $_ssid [$_mode], key: $_key [$_enc]"
  logThis $_wanssid

  if [[ ${#_ssid} -lt 4 ]]; then
   _ERR=1
   showMesg 'SSID must be at least 4 characters long'
  fi
  doUci set $_p'ssid' "${_ssid}"
  _ERR=$?
  [[ $_ERR -gt 0 ]] && showMesg 'New SSID is not set'

  if [[ -z $_key ]]; then
    ## if key is empty set encryption to none and remove key
    doUci set $_p'key' && doUci set $_p'enc' 'none'
    _ERR=$?
  else
    if [[ ${#_key} -lt 8 ]]; then
     _ERR=1
      showMesg 'Passphrase must be at least 8 characters long'
    fi
    doUci set $_p'key' "${_key}" && doUci set $_p'enc' "${_enc}"
    _ERR=$?
    [[ $_ERR -gt 0 ]] && showMesg 'Passphrase is not set'
  fi
  [[ $_ERR -gt 0 ]] && return $_ERR  ##showMesg 'Wireless changes failed'
  doUci commit wireless ##&& showMesg 'Wireless changes applied'
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
  htmlHead "<meta http-equiv='refresh' content='3;url=${HTTP_REFERER}'>"
  echo "<body>
<h1>SG</h1>
<hr>
<h2 style='display:inline'>$_TYPE $_MSG</h2>
<span style='display:inline; margin-left: 50px;'>$_SUBMSG</span>
<hr>
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
  _OUT="$(runSuid /sbin/mtd -e firmware -q write $_FWFILE firmware)"
  _ERR=$?
  [[ $_ERR -gt 0 ]] && showMesg "mtd failed, $_OUT"
  runSuid reboot
  showMesg 'Firmware update is completed, rebooting..' 'this might take up to 60 seconds'
}

rebootNow() {
  logThis "reboot: now!"
  runSuid reboot
  showMesg 'Rebooting..' 'this might take up to 60 seconds'
}

doUci() {
  local _CMD=''
  local _ARG=''
  case $1 in
    get|set|commit) _CMD=$1;;
          *) logThis 'bad UCI command'; headerPrint 405; echo 'bad UCI command'; exit 1 ;;
  esac

  case $2 in
    lanssid) _ARG='wireless.@wifi-iface[0].ssid';;
    lanenc) _ARG='wireless.@wifi-iface[0].encryption';;
    lankey) _ARG='wireless.@wifi-iface[0].key';;
    lanipaddr) _ARG='network.lan.ipaddr';;
    wanifname) _ARG='network.wan.ifname';;
    wanproto) _ARG='network.wan.proto';;
    wanipaddr) _ARG='network.wan.ipaddr';;
    wannetmask) _ARG='network.wan.netmask';;
    wanwifacedis) _ARG='wireless.@wifi-iface[1].disabled';;
    wanssid) _ARG='wireless.@wifi-iface[1].ssid';;
    wanenc) _ARG='wireless.@wifi-iface[1].encryption';;
    wankey) _ARG='wireless.@wifi-iface[1].key';;
    *) if [[ $_CMD == 'commit' ]]; then
        _ARG=$2
       else 
        logThis "bad UCI entry: $2"
        _ERR=1
        showMesg 'bad UCI entry'
       fi ;;
  esac

  if [[ $_CMD == 'get' ]]; then
    if [ ! -z $_ARG ]; then
      /sbin/uci -q get $_ARG || return $?
    fi
  fi

  if [[ $_CMD == 'set' ]]; then
    local _VAL=$3
    if [ -z $_VAL ]; then
      logThis "empty $_ARG value, removing record"
      runSuid /sbin/uci delete $_ARG || ( echo "uci delete $_ARG: error"; exit 1; )
    fi

    if [ ! -z $_ARG ]; then
      logThis "setting $_ARG value"
      runSuid /sbin/uci set $_ARG=$_VAL || ( echo "uci set $_ARG: error"; exit 1; )
    fi
  fi

  if [[ $_CMD == 'commit' ]]; then
    runSuid /sbin/uci commit $_ARG|| echo "uci commit $_ARG: error"
    if [[ "$_ARG" == 'wireless' ]]; then
      runSuid /sbin/wifi || echo 'wifi: error'
    fi
    if [[ "$_ARG" == 'network' ]]; then
      runSuid /etc/init.d/dnsmasq restart && runSuid /etc/init.d/network restart || echo 'network: error'
    fi
  fi
}

getStat() {
  . /usr/share/libubox/jshn.sh
  local _IFACE=$1
  local _IFSTAT=$(runSuid ubus call network.interface.wan status 2>/dev/null)
  logThis "$_IFSTAT"
  json_get_type _IFSTAT ipv4_address
  if json_get_type _IFSTAT ipv4_address && [[ "$_IFSTAT" == 'array' ]]; then
    json_select ipv4_address
    json_get_type _IFSTAT 1
    if [[ "$_IFSTAT" == 'object' ]]; then
      json_select 1
      json_get_var IP4 address
      json_get_var Subnet4 mask
      [[ "$IP4" != '' ]] && [[ "$Subnet4" != '' ]] && IP4="$IP4/$Subnet4"
    fi
  fi
  logThis $IP4
}

htmlHead() {
echo "<!-- obnoxious code below, keep your ports tight -->
<!doctype html>
<html>
<head><title>SuperGlue | Administration</title>
$@
<link rel='stylesheet' type='text/css' href='http://${HTTP_HOST}/resources/admin/admin.css'>
</head>"
}
%>

<% headerPrint '200' %>

<%
## html head
htmlHead

sgver=$(cat /etc/superglue_version)
devmod=$(cat /etc/superglue_model)
openwrt=$(cat /etc/openwrt_version)
wanifname=$(doUci get wanifname || echo 'wlan0') ## TODO fix this
wanproto=$(doUci get wanproto)
wanipaddr=$(doUci get wanipaddr) 
wannetmask=$(doUci get wannetmask)
wanssid=$(doUci get wanssid)
wankey=$(doUci get wankey)

echo "<body>
<h1>SG</h1>
<hr>
<h2 style='display:inline'>Superglue server control panel</h2>
<span style='display:block;'>System version: $sgver | Device: $devmod | OpenWRT: $openwrt</span>
<span style='display:block;'>$(uptime)</span>
<hr>

Update firmware:
<form method='post' action='/admin/updatefw' enctype='multipart/form-data'>
<div id='uploadbox'>
<input id='uploadfile' placeholder='Choose file' disabled='disabled'>
<input id='uploadbtn' name='fwupload' type='file'>
</div>
<input type='submit' value='Upload'>
</form>

<hr>

Internet connection:
<form method='post' action='/admin/wan' name='wan' onchange='formChange();'>
  <div style='display:inline-flex'>
  <div style='display:inline-block;'>
  <select name='wanifname' id='wanifname' style='display:block'>
  <option value='eth0' id='eth' $([[ $wanifname =~ ('eth') ]] && echo 'selected')>Wired (WAN port)</option>
  <option value='wlan1' id='wlan' $([[ $wanifname =~ ('wlan') ]] && echo 'selected')>Wireless (Wi-Fi)</option>
  </select>
  <fieldset id='wanwifi' class='hide'>
  <input type='text' name='wanssid' value='$wanssid'>
  <input type='password' name='wankey' value='$wankey'>
  </fieldset>
  </div>

  <div style='display:inline-block;'>
  <select name='wanproto' id='wanproto' style='display:block'>
  <option value='dhcp' name='dhcp' id='dhcp' $([[ $wanproto == 'dhcp' ]] && echo 'selected')>Automatic (DHCP)</option>
  <option value='stat' name='dhcp' id='stat' $([[ $wanproto == 'static' ]] && echo 'selected')>Manual (Static IP)</option>
  </select>
  <fieldset id='wanaddr' class='hide' >
  <input type='text' name='wanipaddr' id='wanipaddr' value='$wanipaddr'>
  <input type='text' name='wangw' id='wannetmask' value='$wannetmask'>
  </fieldset>
  </div>
  </div>
  <input type='hidden' name='iface' value='wan' class='inline'>
  <input type='submit' value='Apply'>

</form>
<hr>

Local wireless network:
<form method='post' action='/admin/ssidchange'>
  <div style='display:inline-flex'>
  <div style='display:inline-block;'>
    <input type='text' name='lanssid' value='$(doUci get lanssid)'>
    <input type='password' name='lankey' value='$(doUci get lankey)'>
  </div>
  <div style='display:inline-block;'>
    <input type='text' name='lanipaddr' value='$(doUci get lanipaddr)'>
    <input type='hidden' name='iface' value='lan' class='inline'>
  </div>
  </div>
  <input type='submit' value='Apply'>
  
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
Memory:
<pre>$(free)</pre>
<hr>
Storage:
<pre>$(df -h)</pre>
<hr>
Environment:
<pre>$(env)</pre>
<hr>

</body>
<script type='text/javascript' src='http://${HTTP_HOST}/resources/admin/admin.js'></script>

</html>"


%>


