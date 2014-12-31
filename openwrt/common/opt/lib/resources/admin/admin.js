(function() {

var uploadbtn = document.getElementById('uploadbtn');
var uploadfile = document.getElementById('uploadfile');

uploadbtn.addEventListener('change', function () {
  uploadfile.value = this.value.replace(/^.*\\/, "");
  var len = uploadfile.value.length - 7;
  uploadfile.setAttribute('size', len);
  var len = uploadfile.offsetWidth;
  uploadbtn.style.width = len + "px";
});

/* onload check wanconf form selects and set accordingly */
/*  var wanconf = document.getElementById('wanconf');
var selects = wanconf.getElementsByTagName('select');
for (i = 0; i < selects.length; i++) { 
  wanChange(selects[i]);
}
*/

var wanconf = document.getElementById('wanconf');
wanconf.addEventListener('change', function(event) { wanChange(event.target) });

function wanChange(e) {
  var wanwifi = document.getElementById('wanwifi');
  var wanaddr = document.getElementById('wanaddr');

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

var wanssid = document.getElementById('wanssid');
wanssid.addEventListener('focus', function(event) { 
  iwScan();
  event.stopPropagation();
});


/* update uptime output */
(function uptimeUpdate() {
  setTimeout(function() {
    ajaxReq('POST', '/admin/uptime', 'null', function(xmlDoc) {
      //console.log(xmlDoc['response'])
      document.getElementById('uptime').innerHTML = xmlDoc['response'];
    });
    uptimeUpdate();
  }, 5000);
})();

//iwScan();

})();

function iwScan() {
  function comp(a,b) {
    if (a.quality < b.quality)
      return 1;
    if (a.quality > b.quality)
      return -1;
    return 0;
  }
  ajaxReq('POST', '/admin/iwscan', 'null', function(xmlDoc) {
    var res = JSON.parse(xmlDoc['response']);
    var stas = res['results'].sort(comp);
    var wanssid = document.getElementById('wanssid');
    for (var i = 0; i < Object.keys(stas).length; i++) { 
//      console.log(stas[i]['ssid']);
//      console.log(stas[i]);
      var sta;
      if (sta = document.getElementById(stas[i]['ssid'])) {
        console.log('found ' + stas[i]['ssid'] + ' entry');
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
    //  console.log(res);
  });
}

function ajaxReq(url, method, data, callback) {
  var xmlDoc = new XMLHttpRequest();
  xmlDoc.open(url, method, true);
  if (method == 'POST') {
    xmlDoc.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  }
  xmlDoc.onreadystatechange = function() {
    if (xmlDoc.readyState === 4 && xmlDoc.status === 200) {
      callback(xmlDoc);
    }
  }
  xmlDoc.send(data);
}

