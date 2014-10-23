(function() {
  document.getElementById('uploadbtn').onchange = function () {
    document.getElementById('uploadfile').value = this.value.replace(/^.*\\/, "");
    var len = document.getElementById('uploadfile').value.length - 7;
    document.getElementById('uploadfile').setAttribute('size', len);
    var len = document.getElementById('uploadfile').offsetWidth;
    document.getElementById('uploadbtn').style.width = len + "px";
  };
})();

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


