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

wanconf.addEventListener('change', function(event) { wanChange(event.target) });

function wanChange(e) {
  var wanwifi = document.getElementById('wanwifi');
  var wanaddr = document.getElementById('wanaddr');

  switch (e[e.selectedIndex].id) {
    case 'wlan':
      wanwifi.setAttribute('class','show');
      break;
    case 'dhcp':
      wanaddr.setAttribute('class','hide');
      break;
    case 'eth':
      wanwifi.setAttribute('class','hide');
      break
    case 'stat':
      wanaddr.setAttribute('class','show');
      break;
  }
}

/* update uptime output */
(function uptimeUpdate(){
  setTimeout(function(){
    ajaxReq('POST', '/admin/uptime', 'null', function(xmlDoc) {
      //console.log(xmlDoc['response'])
      document.getElementById('uptime').innerHTML = xmlDoc['response'];
    });
    uptimeUpdate();
  }, 5000);
})();


})();

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

/*
function formChange() {
  if (document.activeElement.tagName.toLowerCase() !=  'select') {
    console.log('not select');
    return false;
  }
  aElem = document.activeElement;
  aParent = aElem.parentElement;
  sOpt = aElem[aElem.selectedIndex];
  console.log(aElem.id + sOpt.id);
  if (aElem.id + sOpt.id == 'wanprotostat') {
    document.getElementById('wanaddr').setAttribute('class','show');
  }
  if (aElem.id + sOpt.id == 'wanprotodhcp') {
    document.getElementById('wanaddr').setAttribute('class','hide');
  }
  if (aElem.id + sOpt.id == 'wanifnamewlan') {
    document.getElementById('wanwifi').setAttribute('class','show');
  }
  if (aElem.id + sOpt.id == 'wanifnameeth') {
    document.getElementById('wanwifi').setAttribute('class','hide');
  }
};
*/
