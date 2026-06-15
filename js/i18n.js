(function(){
  var KEY='kbm-lang';
  var labels={'en':'EN','ko':'KR'};
  var codes={'EN':'en','KR':'ko'};

  function get(){return localStorage.getItem(KEY)||'en'}

  function set(lang){
    localStorage.setItem(KEY,lang);
    apply(lang);
  }

  function apply(lang){
    var t=window.KO||{};
    document.querySelectorAll('[data-i18n]').forEach(function(el){
      var k=el.getAttribute('data-i18n');
      if(lang==='en'){
        if(el._orig!=null){
          if(el._isHTML) el.innerHTML=el._orig; else el.textContent=el._orig;
        }
      } else if(t[k]){
        if(el._orig==null){
          el._isHTML=el.querySelector('*')!==null||el.innerHTML.indexOf('<')!==-1;
          el._orig=el._isHTML?el.innerHTML:el.textContent;
        }
        if(el._isHTML) el.innerHTML=t[k]; else el.textContent=t[k];
      }
    });
    // placeholders
    document.querySelectorAll('[data-i18n-ph]').forEach(function(el){
      var k=el.getAttribute('data-i18n-ph');
      if(lang==='en'){
        if(el._origPh) el.placeholder=el._origPh;
      } else if(t[k]){
        if(!el._origPh) el._origPh=el.placeholder;
        el.placeholder=t[k];
      }
    });
    document.querySelectorAll('.nav-lang span').forEach(function(b){
      b.classList.toggle('active',b.textContent.trim()===labels[lang]);
    });
    document.documentElement.lang=lang;
  }

  document.addEventListener('DOMContentLoaded',function(){
    document.querySelectorAll('.nav-lang span').forEach(function(b){
      b.addEventListener('click',function(){
        var c=codes[this.textContent.trim()];
        if(c) set(c);
      });
    });
    var lang=get();
    if(lang!=='en') apply(lang);
  });

  window.I18N={get:get,set:set,apply:apply};
})();
