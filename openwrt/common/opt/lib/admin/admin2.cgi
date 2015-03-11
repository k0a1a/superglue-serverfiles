#!/usr/bin/haserl --shell=/bin/bash  --upload-limit=32768 --upload-dir=/tmp
<%# upload limit: 32Mb %>
<%

## SuperGlue project | http://superglue.it | 2014-2015 | GPLv3
## http://git.superglue.it/superglue/serverfiles
##
## admin2.cgi - control panel for Superglue personal server
## 
## example POST request:
## curl --data-urlencode 'key=value' http://host/uri
##
## returns: 200 (+ output of operation) on success
##          406 (+ error message in debug mode) on error

readonly _WWW='/www'
readonly _PWDFILE="/opt/lib/htpasswd"
readonly _TMP='/tmp'
readonly _LOG="${_WWW}/log/admin.log"
readonly _SCRIPTS='/opt/lib/scripts'
readonly _DEBUG=1
readonly _IFS=$IFS

err() {
  _ERR="$?"
  [[ "$_ERR" -gt 0 ]] || return 0
  logThis "$1"
  headerPrint "${2:='400'}"
  exit "$_ERR"
} 

logThis() {
  [[ "$_DEBUG" -gt 0 ]] || return 0
  local _TYPE='I:'
  [[ "$_ERR" -gt 0 ]] && _TYPE='E:'
  local _TIME; printf -v _TIME '%(%d.%m.%Y %H:%M:%S)T' -1
  printf '%b\n' "$_TIME  $_TYPE ${@} " >> "$_LOG"
  [[ "$_DEBUG" -gt 1 ]] && printf '%b\n' "[verbose] $_TYPE ${1}"
#  exit 0
}

headerPrint() {
  case "$1" in
    200|'') printf '%b' 'Status: 200 OK\r\n';;
    301) printf '%b' "Status: 301 Moved Permanently\r\nLocation: $HTTP_REFERER\r\n";;
    403) printf '%b' 'Status: 403 Forbidden\r\n';;
    405) printf '%b' 'Status: 405 Method Not Allowed\r\n';;
    406) printf '%b' 'Status: 406 Not Acceptable\r\n';;
      *) printf '%b' 'Status: 400 Bad Request\r\n';;
  esac
  printf '%b' 'Content-Type: text/html\r\n\r\n';
}

## faster echo
_echo() {
  printf "%b" "${*}"
}

urlDec() {
  local value=${*//+/%20}
  for part in ${value//%/ \\x}; do
    printf "%b%s" "${part:0:4}" "${part:4}"
  done
}

setQueryVars() {
  _VARS=( ${!POST_*} )
#  local v
#  for v in ${_VARS[@]}; do
  #  echo $v
#    v=$(urlDec "${v}")
#    eval "_${v//POST_/}=${!v}"; 
#  done
  local v
  for v in ${_VARS[@]}; do
    logThis "$v=${!v}"
  done
  #echo $POST_lanssid
  #env
}

getQueryFile() {
#  setQueryVars
  local _UPLD="${HASERL_fwupload_path##*/}"
  logThis "'multipart': decoding stream"
  mv "$_TMP/$_UPLD" "$_TMP/fwupload.bin" 2>/dev/null || _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Firmware upload has failed' '60' 'Reboot your Superglue server and try again'
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
  local _USER='admin'
  local _REALM='superglue'
  [[ -z "${POST_pwd##$POST_pwdd}" ]] || showMesg 'Passwords did not match'
  [[ ${#POST_pwd} -ge 6 ]] || showMesg 'Password must be at least 6 characters long'
  local _HASH=$(printf '%s' "$_USER:$_REALM:${POST_pwd}" | md5sum | cut -b -32)
  _OUT=$(printf '%b' "${POST_pwd}\n${POST_pwd}\n" | passwd root 2>&1) &&
  _OUT=$(printf '%b' "$_USER:$_REALM:$_HASH\n" > $_PWDFILE 2>&1)
  _ERR=$?
  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Password change failed!' '5' "$_OUT -"
  else
    showMesg 'Password is changed' '2'
  fi
}

lanAddr() {
  logThis "new LAN addr is: $POST_lanipaddr"
  validIp $POST_lanipaddr || showMesg 'Not valid network address'
  doUci set lanipaddr $POST_lanipaddr &&
  doUci commit network &&
  dtach -n -zE $_SCRIPTS/net-restart.sh &&
  showMesg 'New network address is set' '30' "Your server is now accessible under <a href='http://superglue.local/admin'>http://superglue.local/admin</a>" ||
  { _ERR=1; showMesg 'Setting network address failed'; }
}

wanSet() {
  if [[ ! -z $POST_wanifname ]]; then
    ## eth and wlan wan cases are different!
    ## eth wan requires:
    ##   config interface 'wan'
    ##     option proto 'dhcp'
    ##     option ifname 'eth0'
    ##
    ## wlan wan requires:
    ##   config interface 'wan'
    ##     option proto 'dhcp' (and no 'option ifname' specified!)

    logThis "wan.ifname=$POST_wanifname"
    if [[ $POST_wanifname == 'eth0' ]]; then
      doUci set wanifname $POST_wanifname
      doUci set wanwifacedis '1'
    elif [[ $POST_wanifname == 'wlan1' ]]; then
      doUci set wanifname ''
      doUci set wanwifacedis ''
    fi
    if [[ $POST_wanproto == 'dhcp' ]]; then
      doUci set wanproto dhcp
      doUci set wanipaddr ''
      doUci set wanmask ''
      doUci set wangw ''
      doUci set wandns ''
    elif [[ $POST_wanproto == 'static' ]]; then
      logThis "wan.ipaddr=$POST_wanipaddr"
      validIp $POST_wanipaddr || showMesg 'Our IP address is not valid' '3' 'make sure to use correct address notation'
      validIp $POST_wangw || showMesg 'Gateway is not a valid IP address' '3' 'make sure to use correct address notation'
      validIp $POST_wandns || showMesg 'DNS is not a valid IP address' '3' 'make sure to use correct address notation'
      doUci set wanproto static
      doUci set wanipaddr $POST_wanipaddr
      doUci set wanmask '255.255.255.0' ## fix me
      doUci set wangw $POST_wangw
      doUci set wandns $POST_wandns
    fi
    if [[ $POST_wanifname == 'wlan1' ]]; then
      ssidChange || showMesg 'wanSet: Wireless configuration failed'
    else
      doUci commit network
      doUci commit wireless
      dtach -n -zE $_SCRIPTS/net-restart.sh
    fi
    _ERR=$?
#    logThis "return: $? ; error: $_ERR"
    if [[ $_ERR -gt 0 ]]; then
      showMesg 'Internet connection is being configured' '25' 'check your Internet connection on completion'
    else
      showMesg 'Configuring Internet connection failed'
    fi
  fi
}

ssidChange() {
  ## check for iface
  [[ $POST_iface =~ ^('wan'|'lan')$ ]] || showMesg 'Error changing wireless settings' '5' 'unknown or unconfigured interface'
  logThis "$POST_iface is being set"

  _p=$POST_iface

  ## default enc for now
  local _enc='psk2'
  if [[ $POST_iface == 'wan' ]]; then
    local _mode='sta'
    local _ssid="${POST_wanssid}"
    local _key="${POST_wankey}"
  else 
    local _mode='ap'
    local _ssid="${POST_lanssid}"
    local _key="${POST_lankey}"
  fi

  #logThis "ssid: $_ssid [$_mode], key: $_key [$_enc]"
  #logThis $POST_wanssid

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
  [[ $_ERR -gt 0 ]] && showMesg 'ssidChange: Wireless configuration failed'
  if [[ $POST_iface == 'lan' ]]; then
    if [[ "$(doUci get lanipaddr)" !=  "${POST_lanipaddr}" ]]; then
      logThis 'local IP was changed'
      lanAddr
    fi
  fi
  doUci commit wireless
  _ERR=$?

  if [[ $_ERR -gt 0 ]]; then
    showMesg 'Configuration failed'
  else
    dtach -n -zE $_SCRIPTS/net-restart.sh &>/dev/null
  fi

  if [[ $POST_iface == 'lan' ]]; then
    showMesg 'Local network configuration is progress' '30' 'check your connection on completion - '
  fi
    ## in this case wanSet() handles success message
}

showMesg() {
  local _RET=$?
  local _MSG=$1
  local _TIMEOUT=$2
  local _SUBMSG=$3
  ## if set, global _ERR value prevails 
#  logThis "return: $_RET , error: $_ERR"
#  if [[ ! -z $_ERR ]] && [[ $_ERR -ne $_RET ]]; then 
#    _ERR=$_RET
#    logThis "forcing _ERR value: $_ERR"
#  fi
  _ERR=$_RET
  _MSG=${_MSG:='Configuration'}
  _TIMEOUT=${_TIMEOUT:='5'}
  _SUBMSG="${_SUBMSG} <span id='timeout'>${_TIMEOUT}</span> seconds to get ready.."
  if [[ $_ERR -gt 0 ]]; then
    local _TYPE='ERROR: '
    headerPrint 406
  else
    local _TYPE='OK: '
    headerPrint 200
  fi
  htmlHead "<meta http-equiv='refresh' content='${_TIMEOUT};url=http://${HTTP_HOST}/admin'>"
  _echo "<body>
  <h1>Superglue control panel</h1>
  <img src='http://${HTTP_HOST}/resources/img/superglueLogo.png' class='logo'>
  <hr>
  <h2 style='display:inline'>$_TYPE $_MSG</h2>
  <span style='display:block'>$_SUBMSG</span>
  <hr>
  </body>
  <script type='text/javascript'>(function(e){var t=document.getElementById(e);var n=t.innerHTML;var r=setInterval(function(){if(n==0){t.innerHTML='0';clearInterval(r);return}t.innerHTML=n;n--},1e3)})('timeout')
  </script>
  </html>"
  exit $_ERR
}

updateFw() {
  local _FWFILE="${_TMP}/fwupload.bin"
  _OUT="$(sysupgrade -T $_FWFILE 2>&1)" ||
  { _ERR=$?; rm -rf $_FWFILE; showMesg 'This is not a firmware!' '3' "$_OUT"; }
  [[ $POST_fwreset == 'on' ]] && { _FWRESET='-n'; logThis 'fw reset requested'; }
  ## using dtach to prevent sysupgrade getting killed
  dtach -n -zE sysupgrade $_FWRESET $_FWFILE >/dev/null &&
  showMesg 'Firmware update is in progress..' '120' 'DO NOT INTERRUPT!' ||
  { _ERR=$?; rm -rf $_FWFILE; showMesg 'Firmware update failed..' '3' "$_OUT"; }
}

usbInit() {
  . $_SCRIPTS/usb-part.sh
  _OUT="$(usbPart)" && 
  showMesg 'USB storage initialization is completed' '30' ||
  showMesg "USB init failed!\n$_OUT"
#  logThis 'usb init..'
}

rebootNow() {
  logThis "reboot: now!"
  reboot
  showMesg 'Rebooting..' '60'
}

upTime() {
  local _T="$(uptime)" &&
  { headerPrint 200; printf '%b' "$_T\n"; exit 0; } ||
  headerPrint 406
}

iwScan() {
  . $_SCRIPTS/iw-scan.sh
  headerPrint 200
  iwScan
  exit 0
}

findUsbstor() {
  local _P='/sys/block/'
  local _D _DEV
  for _D in ${_P}sd*; do
    _DEV=$(readlink -f ${_D}/device)
    if [[ ${_DEV/usb} != $_DEV ]]; then
      _USBDEV="/dev/${_D/$_P}"
    fi
  done
  [[ $_USBDEV ]] || return 1
}

storageInfo() {
  if mountpoint -q $_WWW; then
    IFS=$'\n' _STOR=( $(df -h $_WWW) ) IFS=$_IFS
    _STOR=( ${_STOR[1]} )
  else
    return 1
  fi
}

swapInfo() {
  IFS=$'\n' _SWAP=( $(swapon -s) ) IFS=$_IFS
  if [[ ${_SWAP[1]} ]]; then
    IFS=$'\t' _SWAP=( ${_SWAP[1]} ) IFS=$_IFS
    ## for the lack of floats add trailing 0
    ## divide by 1023 and split last digit by a period
    _SWAP[1]="$((${_SWAP[1]}0/1023))"
    _SWAP[1]="${_SWAP[1]%?}.${_SWAP[1]/??}M"
  else
    unset _SWAP
    return 1
  fi
}

trimSpaces() {
  local v="$*"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  return "$v"
}

dynDns() {
  ## curently only http://freedns.afraid.org is supported
  [[ $POST_dyndnsname && $POST_dyndnsuser && $POST_dyndnspass ]] || showMesg 'All values must be set!'
  
  doUci set dyndnsname "$POST_dyndnsname" &&
  doUci set dyndnsuser "$POST_dyndnsuser" &&
  doUci set dyndnspass "$POST_dyndnspass" || showMesg 'DynDNS settings failed..'

  ## create sha1 string per http://freedns.afraid.org/api
  local _DURL
  local _AFRAID='http://freedns.afraid.org/api/?action=getdyndns&sha='
  _DURL=$(_echo "$POST_dyndnsuser|$POST_dyndnspass" | sha1sum)
  _DURL="$_AFRAID${_DURL/ -/}"
  _DURL="$(wget -q $_DURL -O -)"
  local _L
  local _RES
  for _L in $_DURL
    do case $_L in 
      "${POST_dyndnsname}|"*) IFS='|' _RES=( $_L ); break;; 
      'ERROR'*) _RES=1; break;;
      *) unset _RES;;
    esac;
  done
  [[ ! $_RES ]] && showMesg 'Domain name is not found' '10' 'Make sure you entered correct domain name -'
  [[ $_RES -eq 1 ]] && showMesg 'Authentication failed' '10' 'Check your username and password and try again -'

  logThis "${_RES[@]}"

  doUci set dyndnsurl "${_RES[2]}" &&
  doUci set dyndnsdis '' &&

  doUci commit  

  showMesg 'DynDNS configuration is in progress..' '10' 'After completion, your URL will become available with in 10-15 minutes -'

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
    wanmask) _ARG='network.wan.netmask';;
    wangw) _ARG='network.wan.gateway';;
    wandns) _ARG='network.wan.dns';;
    wanwifacedis) _ARG='wireless.@wifi-iface[1].disabled';;
    wanssid) _ARG='wireless.@wifi-iface[1].ssid';;
    wanenc) _ARG='wireless.@wifi-iface[1].encryption';;
    wankey) _ARG='wireless.@wifi-iface[1].key';;
    dyndnsdis) _ARG='superglue.dyndns.disabled';;
    dyndnsurl) _ARG='superglue.dyndns.updateurl';;
    dyndnsname) _ARG='superglue.dyndns.domainname';;
    dyndnsuser) _ARG='superglue.dyndns.username';;
    dyndnspass) _ARG='superglue.dyndns.password';;
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
      /sbin/uci delete $_ARG || ( echo "uci delete $_ARG: error"; exit 1; )
    fi

    if [ ! -z $_ARG ]; then
      logThis "setting $_ARG value"
      /sbin/uci set $_ARG=$_VAL || ( echo "uci set $_ARG: error"; exit 1; )
    fi
  fi

  if [[ $_CMD == 'commit' ]]; then
    /sbin/uci commit $_ARG || echo "uci commit $_ARG: error"
  fi
}


## call with argument to inject additional lines
## ie: htmlhead "<meta http-equiv='refresh' content='2;URL=http://${HTTP_REFERER}'>"

htmlHead() {
_echo "<!-- obnoxious code below, keep your ports tight -->
<!doctype html>
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=UTF-8' />
<meta http-equiv='Cache-Control' content='no-cache, no-store, must-revalidate' />
<meta http-equiv='Pragma' content='no-cache' />
<meta http-equiv='Expires' content='0' />
<link rel='icon' href='http://${HTTP_HOST}/resources/img/favicon.ico' type='image/x-icon' />
<title>Superglue | Control panel</title>
<link rel='stylesheet' type='text/css' href='http://${HTTP_HOST}/resources/admin/admin.css' />
$@
</head>"
}

footerBody() {
_echo "</body>
<script type='text/javascript' src='http://${HTTP_HOST}/resources/admin/admin.js'></script>
</html>"
}

if [[ "${REQUEST_METHOD^^}" == "POST" ]]; then
  [[ $CONTENT_LENGTH -gt 0 ]] || err 'content length is zero, 301 back to referer' '301'
  case "${CONTENT_TYPE^^}" in 
    APPLICATION/X-WWW-FORM-URLENCODED*) setQueryVars;;
                  MULTIPART/FORM-DATA*) getQueryFile;;
                                     *) _ERR=1; _OUT='this is not a post';;
  esac

  case $REQUEST_URI in
                *pwdchange) pwdChange;;
               *ssidchange) ssidChange;;
                  *lanaddr) lanAddr;;
                 *updatefw) updateFw;;
                  *usbinit) usbInit;;
                *rebootnow) rebootNow;;
                      *wan) wanSet;;
                   *uptime) upTime;;
                   *iwscan) iwScan;;
                   *dyndns) dynDns;;
                         *) logThis 'bad action'; headerPrint 405; 
                            echo 'no such thing'; exit 1;;
  esac
fi

headerPrint '200'
htmlHead

read sgver < /etc/superglue_version
read devmod < /etc/superglue_model
read openwrt < /etc/openwrt_version

. /opt/lib/scripts/jshn-helper.sh

## this does not work when iface isn't configured
IFS=","
wan=( $(ifaceStat wan) )
IFS=$OFS

wanifname=${wan[3]}
wanproto=$(doUci get wanproto)
wanipaddr=${wan[0]}
wangw=${wan[2]}
wandns=${wan[5]}
wanuptime=${wan[4]}
wanssid=$(doUci get wanssid)
wankey=$(doUci get wankey)

%>

<body>
  <h1>Superglue control panel</h1>
  <img src='http://<% _echo "${HTTP_HOST}" %>/resources/img/superglueLogo.png' class='logo'>

<section class='inert'>
  <span style='display:block;'><% printf "System version: %s | Device: %s | OpenWRT: %s" "$sgver" "$devmod" "$openwrt" %></span>
  <span style='display:block;' id='uptime'><% uptime %></span>
</section>

<section>
  <h2>Internet connection:</h2>
  <form method='post' action='/admin/wan' name='wan' class='elem' id='wanconf'>
  <div style='display:inline-flex'>
  <div style='display:inline-block;'>
  <select name='wanifname' id='wanifname' style='display:block'>
  <option value='eth0' id='eth' <% ( [[ $wanifname =~ ('eth') ]] && _echo 'selected' ) %> >Wired (WAN port)</option>
  <option value='wlan1' id='wlan' <% ( [[ $wanifname =~ ('wlan') ]] && _echo 'selected' ) %> >Wireless (WiFi)</option>
  </select>
  <fieldset id='wanwifi' <% ( [[ $wanifname =~ ('wlan') ]] && _echo "class='show elem'" || _echo "class='hide elem'" ) %>>
    
  <select name='wanssid' id='wanssid' class='elem' style='display:block'>
  <% if [[ -z $wanssid ]]; then
    _echo "<option id='scan' disabled>select a network..</option>"
  else
    _echo "<option id=$wanssid selected>$wanssid</option>"
  fi %>
  </select>
  <input type='password' name='wankey' placeholder='passphrase' value='<% _echo $wankey %>'>

  </fieldset>

  <span class='help'>help</span>
  </div>

  <div style='display:inline-block;'>
  <select name='wanproto' id='wanproto' style='display:block'>
  <option value='dhcp' name='dhcp' id='dhcp' <% ([[ $wanproto == 'dhcp' ]] && _echo 'selected') %>>Automatic (DHCP)</option>
  <option value='static' name='stat' id='stat' <% ([[ $wanproto == 'static' ]] && _echo 'selected') %>>Manual (Static IP)</option>
  </select>
  <fieldset id='wanaddr' class='elem'>
  <input type='text' name='wanipaddr' id='wanipaddr' value='<% _echo $wanipaddr %>' <% ( [[ $wanproto =~ ('dhcp') ]] && _echo "readonly" ) %> placeholder='ip address'>
  <input type='text' name='wangw' id='wangw' value='<% _echo $wangw %>' <% ( [[ $wanproto =~ ('dhcp') ]] && _echo "readonly" ) %> placeholder='gateway/router'>
  <input type='text' name='wandns' id='wandns' value='<% _echo $wandns %>' <% ( [[ $wanproto =~ ('dhcp') ]] && _echo "readonly" ) %> placeholder='dns server'>
  </fieldset>
  </div>
  </div>
  <input type='hidden' name='iface' value='wan' class='inline'>
  <input type='submit' id='wansubmit' value='Apply'>
  </form>
  <span class='help'>help</span>
</section>

<section>
  <h2>Domain name:</h2>
  <form method='post' action='/admin/dyndns' name='dyndns' id='afraid'>
  <div style='display:inline-flex'>
    <div style='display:inline-block;'>
      <input type='text' name='dyndnsname' id='dyndnsname' value='<% _echo $dyndnsname %>' placeholder='domain name' class='block'>
    </div>
    <div style='display:inline-block;'>
    <input type='text' name='dyndnsuser' id='dyndnsuser' value='<% _echo $dyndnsuser %>' placeholder='dyndns username' class='block'>
    <input type='password' name='dyndnspass' id='dyndnspass' value='<% _echo $dyndnspass %>' placeholder='dyndns password' class='block'>
    </div>
  </div>
  <input type='hidden' name='dns' value='apply' class='inline'>
  <input type='submit' value='Apply'>
  </form>

  <h2>Dynamic DNS:</h2>
    Register your free domain name (external <a target='_new' href='http://freedns.afraid.org/'>Free DNS</a> service, will open in a new tab)
    <form target='_new' action='http://freedns.afraid.org/subdomain/edit.php'>
    <div style='display:inline-flex'>
      <div style='display:inline-block;'>
        <input type='text' name='subdomain' placeholder='yourname' class='inline'>
      </div>
      <div style='display:inline-block;'>
        <select name='edit_domain_id' class='inline'>
        <option value='1035903'>spgl.cc</option>
        <option value='1035903'>spgl.it</option>
        </select>
      </div>
    </div>
    <input type='submit' name='submit' value="next &gt;&gt;">
    <input type='hidden' name='web_panel' value='1'>
    <input type='hidden' name='ref' value='750930'>
    </form>
   
 <span class='help'>help</span>
</section>

<section>
<h2>Local wireless network:</h2>
<form method='post' action='/admin/ssidchange'>
  <div style='display:inline-flex'>
  <div style='display:inline-block;'>
    <input type='text' name='lanssid' value='<% doUci get lanssid %>'>
    <input type='password' name='lankey' value='<% doUci get lankey %>'>
  </div>
  <div style='display:inline-block;'>
    <input type='text' name='lanipaddr' value='<% doUci get lanipaddr %>'>
    <input type='hidden' name='iface' value='lan'>
  </div>
  </div>
    <input type='submit' value='Apply' data-wait='Configuring..'>  
</form>
  <span class='help'>help</span>
</section>

<section>
<h2>Storage:</h2>
<% if findUsbstor; then %>

  <% if storageInfo; then %>
    <div>File storage: <% _echo "${_STOR[2]} used, ${_STOR[3]} available" %></div>
    <div>Swap: <% swapInfo && _echo "${_SWAP[1]}" || _echo '<b>n/a</b>' %></div>
  <% else %>
    <div>USB storage device must be initialized</div>
    <form method='post' action='/admin/usbinit'>
    <input type='hidden' name='dev' value='<% _echo $_USBDEV %>'>
    <input type='submit' value='Initialize'>
    </form>
  <% fi %>

<% else %>

  <div><h3>USB storage device not found!</h3>Please check and try again</div>

<% fi %>

<span class='help'>help</span>
</section>

<section>
<h2>Change password:</h2>
<form method='post' action='/admin/pwdchange'>
  <div style='display:inline-flex'>
  <div style='display:inline-block;'>
    <input type='text' name='usr' value='admin' readonly>
  </div>
  <div style='display:inline-block;'>
    <input type='password' name='pwd' placeholder='password' value=''>
    <input type='password' name='pwdd' placeholder='password again' value=''>
  </div>
  </div>
    <input type='submit' value='Apply'>
</form>
<span class='help'>help</span>
</section>


<section>
  <h2>Firmware upgrade:</h2>
  <form method='post' action='/admin/updatefw' enctype='multipart/form-data'>
  <div id='uploadbox'>
    <input id='uploadfile' placeholder='Select a file..' class='elem' disabled='disabled'>
    <input id='uploadbtn' class='elem' name='fwupload' type='file'>
  </div>
  <div style='display:inline-block;'>
    <input type='checkbox' name='fwreset' id='fw-resetbox' />
    <label for='fw-resetbox'>Reset all settings</label>
  </div>
  <input type='submit' value='Upload' data-wait='Uploading, do NOT interrupt!'>
  </form>
  <span class='help'>help</span>
</section>

<section>
  <h2></h2>
  <form action='/admin/rebootnow' method='post' class='inline'>
    <input type='hidden' name='reboot' value='now' class='inline'>
    <input type='submit' value='Reboot' class='inline'>
  </form>

  <form action='http://logout@<% _echo ${HTTP_HOST} %>/admin' method='get' class='inline'>
    <input type='submit' value='Logout' class='inline'>
  </form>
</section>

<div style='height:200px'></div>
<hr>
Memory:
<pre><% free %></pre>
<hr>
Storage:
<pre><% df -h %></pre>
<hr>
Environment:
<pre><% env %></pre>
<hr>

<%
footerBody
exit 0
%>
