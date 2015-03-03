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
  console.log('wanssid trigered');
  iwScan(e.target);
  e.stopPropagation();
});

/* update WAN form based on what iface is chosen */
function wanChange(e) {
  switch (e[e.selectedIndex].id) {
    case 'wlan':
      wanwifi.setAttribute('class','show');
//      iwScan();
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

/* get results from iwlist and show in the UI */
function iwScan(e) {
  console.log('scanning wifi..');
  var scan = document.createElement('option');
  var len = 0;
  scan.selected = true;
  scan.disabled = true;
  scan.style.visibility = 'hidden';
  scan.id = 'scanning';
  scan.innerHTML = 'scanning for networks..';
  if (e.firstChild != scan) {
    e.insertBefore(scan, e.firstChild);
  }
  e.options.length = 1;
  //e.size = 0;

  function getIwscan() {
    ajaxReq('POST', '/admin/iwscan', 'null', function(xhr) {
      var res = JSON.parse(xhr['response']);
      var aps = res['results'].sort(compSort); /* get APs */
      len = Object.keys(aps).length;
      //console.log(len, aps);
      for (i = 0; i < len; i++) {
        console.log(aps[i]['ssid']);
        console.log(document.getElementById(aps[i]['ssid']));
        if (document.getElementById(aps[i]['ssid'])) {
          console.log('found ' + aps[i]['ssid'] + ' entry');
          /* TODO: update existing records */
        } else {
          ap = document.createElement('option');
          ap.id = aps[i]['ssid'];
          ap.setAttribute('data-quality',  aps[i]['quality']);
          if (aps[i]['encryption']['enabled']) {
            ap.setAttribute('data-enc', 'wpa2');
          } else {
            ap.setAttribute('data-enc', 'false');
          }
          ap.innerHTML = aps[i]['ssid'];
          e.appendChild(ap);
        }
      }
      if ( len > 0 ) {
        //e.removeChild(scan);
        e.options.length = len;
        scan.innerHTML = 'select a network..';
        e.selectedIndex=0;
      } else {
        console.log('no results, running iwScan again');
        iwScan()
      }
    });
  }
  getIwscan();
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

/* simple XHR */
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
  
/* sort by comparing a & b values */
function compSort(a,b) {
  if (a.quality < b.quality)
     return 1;
  if (a.quality > b.quality)
    return -1;
  return 0;
}
