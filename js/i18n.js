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
    applyTextMap(lang);
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
    applyPlaceholderMap(lang);
    document.querySelectorAll('.nav-lang span').forEach(function(b){
      b.classList.toggle('active',b.textContent.trim()===labels[lang]);
    });
    document.documentElement.lang=lang;
  }

  function applyTextMap(lang){
    var map=window.KO_TEXT||{};
    if(!document.body) return;
    var walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{
      acceptNode:function(node){
        var p=node.parentElement;
        if(!p) return NodeFilter.FILTER_REJECT;
        if(!node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
        if(p.closest('script,style,template,.nav-lang,[data-i18n]')) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var node;
    while((node=walker.nextNode())){
      if(lang==='en'){
        if(node._origText!=null) node.nodeValue=node._origText;
        continue;
      }
      if(node._origText==null) node._origText=node.nodeValue;
      var source=node._origText.trim();
      if(map[source]){
        var leading=(node._origText.match(/^\s*/)||[''])[0];
        var trailing=(node._origText.match(/\s*$/)||[''])[0];
        node.nodeValue=leading+map[source]+trailing;
      }
    }
  }

  function applyPlaceholderMap(lang){
    var map=window.KO_PH||{};
    document.querySelectorAll('input[placeholder],textarea[placeholder]').forEach(function(el){
      if(lang==='en'){
        if(el._origAutoPh!=null) el.placeholder=el._origAutoPh;
        return;
      }
      if(el._origAutoPh==null) el._origAutoPh=el.placeholder;
      var source=el._origAutoPh.trim();
      if(map[source]) el.placeholder=map[source];
    });
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
