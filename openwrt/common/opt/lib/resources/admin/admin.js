var uploadbtn = document.getElementById('uploadbtn');
var uploadfile = document.getElementById('uploadfile');
var wanconf = document.getElementById('wanconf');
var wanssid = document.getElementById('wanssid');
var wanwifi = document.getElementById('wanwifi');
var wanaddr = document.getElementById('wanaddr');

uploadbtn.addEventListener('change', function () {
  uploadfile.value = this.value.replace(/^.*\\/, "");
  var len = uploadfile.value.length - 7;
  uploadfile.setAttribute('size', len);
  var len = uploadfile.offsetWidth;
  uploadbtn.style.width = len + "px";
});

wanconf.addEventListener('change', function(e) { 
  wanChange(e.target)
});

wanssid.addEventListener('focus', function(e) { 
  iwScan();
  e.stopPropagation();
});

function wanChange(e) {
  switch (e[e.selectedIndex].id) {
    case 'wlan':
      wanwifi.setAttribute('class','show');
      iwScan();
      break;
    case 'dhcp':
    //  wanaddr.setAttribute('class','hide');
      for (var i = 0; i < wanaddr.children.length; i++) {
        wanaddr.children[i].setAttribute('readonly', true);
      }
      break;
    case 'eth':
      wanwifi.setAttribute('class','hide');
      break
    case 'stat':
    //  wanaddr.setAttribute('class','show');
      for (var i = 0; i < wanaddr.children.length; i++) {
        wanaddr.children[i].removeAttribute('readonly');
      }
    break;
  }
}

var submitbtns = document.querySelectorAll('input[type="submit"]');
for (var i=0; i < submitbtns.length; i++){
  submitbtns[i].addEventListener('click', function(e) {
  if (e.target.hasAttribute('data-wait')) {
    e.target.value = e.target.getAttribute('data-wait');
  } else e.target.value = 'Working, please wait..';
  e.stopPropagation();
  }, false);
}

/* update uptime output */
function uptimeUpdate() {
  function run() {
    ajaxReq('POST', '/admin/uptime', 'null', function(xhr) {
      if (xhr['response'] != '') {
        document.getElementById('uptime').innerHTML = xhr['response'];
      }
    }); 
  }
  return setInterval(run, 5000);
}

var uptime = window.uptimeUpdate();

function iwScan() {
  function comp(a,b) {
    if (a.quality < b.quality)
      return 1;
    if (a.quality > b.quality)
      return -1;
    return 0;
  }
  ajaxReq('POST', '/admin/iwscan', 'null', function(xhr) {
    var res = JSON.parse(xhr['response']);
    var stas = res['results'].sort(comp);
    var wanssid = document.getElementById('wanssid');
    for (var i = 0; i < Object.keys(stas).length; i++) { 
      var sta;
      if (sta = document.getElementById(stas[i]['ssid'])) {
        //console.log('found ' + stas[i]['ssid'] + ' entry');
      } else {
        sta = document.createElement('option');
        sta.id = stas[i]['ssid'];
        sta.setAttribute('data-quality',  stas[i]['quality']);
        if (stas[i]['encryption']['enabled']) {
          sta.setAttribute('data-enc', 'wpa2');
        } else {
          sta.setAttribute('data-enc', 'false');
        }
        sta.innerHTML = stas[i]['ssid'];
        wanssid.appendChild(sta);
      }
    }
  });
}

iwScan()

function ajaxReq(method, url, data, callback) {
  var xhr = new XMLHttpRequest();
  xhr.open(method, url, true);
  xhr.onerror = function() { clearInterval(uptime) }
  xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  xhr.onreadystatechange = function() {
    if (xhr.readyState == 4 && xhr.status == 200) { 
      callback(xhr);
    }
  }
  xhr.send(data);
}

