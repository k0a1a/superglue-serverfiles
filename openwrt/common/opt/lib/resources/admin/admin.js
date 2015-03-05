document.addEventListener('DOMContentLoaded', function() {

/* make wanted 'elem' class elements to array or vars */
var el = [];
(function() {
  x = document.getElementsByClassName('elem');
  for (i = 0; i < x.length; i++ ) {
    el_id = x[i].id;
    el.push(el_id);
    el[el_id] = document.getElementById(el_id);
  }
})();

/*
var uploadbtn = document.getElementById('uploadbtn');
var uploadfile = document.getElementById('uploadfile');
var wanconf = document.getElementById('wanconf');
var wanssid = document.getElementById('wanssid');
var wanwifi = document.getElementById('wanwifi');
var wanaddr = document.getElementById('wanaddr');
*/

el['uploadbtn'].addEventListener('change', function (e) {
  el['uploadfile'].value = this.value.replace(/^.*\\/, "");
  var len = el['uploadfile'].value.length - 7;
  el['uploadfile'].setAttribute('size', len);
  var len = el['uploadfile'].offsetWidth;
  el['uploadbtn'].style.width = len + "px";
  e.stopPropagation();
});

/* all submit buttons */
var submitbtns = document.querySelectorAll('input[type="submit"]');
for (var i=0; i < submitbtns.length; i++){
  submitbtns[i].addEventListener('click', function(e) {
  if (e.target.hasAttribute('data-wait')) {
    e.target.value = e.target.getAttribute('data-wait');
  } else e.target.value = 'Working, please wait..';
  e.stopPropagation();
  }, false);
}

el['wanconf'].addEventListener('change', function(e) { 
  wanChange(e.target)
  e.stopPropagation();
});

el['wanssid'].addEventListener('focus', function(e) {
  if (e.target.length == 1) {
    iwScan(e.target);
    e.target.blur();
    getFirstchild(e.target).blur();
    getFirstchild(e.target).style.display = 'none';
  } else {
    iwScan(e.target);
  }
  e.stopPropagation();
});

/* update WAN form based on what iface is chosen */
function wanChange(e) {
  switch (e[e.selectedIndex].id) {
    case 'wlan':
      el['wanwifi'].setAttribute('class','show');
      //iwScan(el['wanssid']);
      break;
    case 'dhcp':
    //  wanaddr.setAttribute('class','hide');
      for (var i = 0; i < el['wanaddr'].children.length; i++) {
        el['wanaddr'].children[i].setAttribute('readonly', true);
      }
      break;
    case 'eth':
      el['wanwifi'].setAttribute('class','hide');
      break
    case 'stat':
    //  wanaddr.setAttribute('class','show');
      for (var i = 0; i < el['wanaddr'].children.length; i++) {
        el['wanaddr'].children[i].removeAttribute('readonly');
      }
    break;
  }
}

/* get results from iwlist and show in the UI */
function iwScan(e) {
  console.log('scanning wifi..');
  if (getFirstchild(e).id != 'scan') {
    scan_el = document.createElement('option');
    scan_el.selected = true;
    scan_el.disabled = true;
    scan_el.id = 'scan';
    e.insertBefore(scan_el, e.firstChild);
  } else scan_el = document.getElementById('scan');
  scan_el.textContent = 'scanning for networks..';
  scan_el.selected = 1;
  ajaxReq('POST', '/admin/iwscan', 'null', function(xhr) {
    res = JSON.parse(xhr['response']);
    aps = res['results'].sort(compSort); /* get APs */
    aps_num = Object.keys(aps).length;
    for (i = 0; i < aps_num; i++) {
      // check if AP is already in the DOM
      if (document.getElementById(aps[i]['ssid'])) {
        //console.log('found ' + aps[i]['ssid'] + ' entry');
        /* TODO: update existing records */
      } else {
        ap = document.createElement('option');
        ap.id = aps[i]['ssid'];
        ap.setAttribute('data-bssid',  aps[i]['bssid']);
        ap.setAttribute('data-quality',  aps[i]['quality']);
        if (aps[i]['encryption']['enabled']) {
          ap.setAttribute('data-enc', 'wpa2');
        } else {
          ap.setAttribute('data-enc', 'false');
        }
        ap.textContent = aps[i]['ssid'] ? aps[i]['ssid'] : '[hidden network]';
        e.appendChild(ap);
      }
    }
    scan_el.textContent = 'select a network..';
    if (! aps_num) {
      scan_el.textContent = 'no scan results..';
      console.log('no scan results');
    }
  });
  e.blur();
  // just focusing someother element 
  // document.getElementById('wansubmit').focus();
  return
}

/* v simple XHR */
function ajaxReq(method, url, data, callback) {
  var xhr = new XMLHttpRequest();
  xhr.open(method, url, true);
  xhr.onerror = function() { clearInterval(uptime); console.log('network error, dying'); return; }
  xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  xhr.onreadystatechange = function() {
    if (xhr.readyState == 4 && xhr.status == 200) { 
      callback(xhr);
    }
  }
  xhr.send(data);
}
 
/* 
   update uptime output
   we just run ahead
                        */
var uptime = (function uptimeUpdate() {
  function run() {
    ajaxReq('POST', '/admin/uptime', 'null', function(xhr) {
      if (xhr['response'] != '') {
        document.getElementById('uptime').textContent = xhr['response'];
      }
    }); 
  }
  return setInterval(run, 5000);
})();
 
/* sort by comparing a and b */
function compSort(a,b) {
  if (a.quality < b.quality)
     return 1;
  if (a.quality > b.quality)
    return -1;
  return 0;
}

/* because firstChild returns whitespaces too */
function getFirstchild(n) {
  x = n.firstChild;
  while (x.nodeType != 1) {
    x = x.nextSibling;
  }
  return x;
}

});
