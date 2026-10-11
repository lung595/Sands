// Offscreen check of the alex-row page (WebKitGTK through gjs): console errors, overlaps, overflow,
// clipped text, target sizes and contrast failures, for every theme, mode, width, Alex state, name and choice.
// Usage: gjs tools/check.js "$PWD/index.html"
imports.gi.versions.Gtk = '4.0'; imports.gi.versions.WebKit = '6.0';
const { Gtk, WebKit, GLib, Gio } = imports.gi;
Gtk.init();
const loop = GLib.MainLoop.new(null, false);
const ucm = new WebKit.UserContentManager();
ucm.add_script(new WebKit.UserScript("window.__errs=[];window.addEventListener('error',e=>__errs.push(e.message));const ce=console.error;console.error=(...a)=>{__errs.push(a.join(' '));ce(...a)};", WebKit.UserContentInjectedFrames.TOP_FRAME, WebKit.UserScriptInjectionTime.START, null, null));
const wv = new WebKit.WebView({ user_content_manager: ucm });
const win = new Gtk.Window({ default_width: 1440, default_height: 1400, child: wv });
win.realize();
const CHECK = `(()=>{
const out={errs:__errs.slice(),bad:[],cases:0,geo:{}};
const sel='.tt,.hp,.sg,.strip,.cost,.cpill,.hn b,.hn small,.gh,.tog,h3,.ent';
const R=e=>e.getBoundingClientRect();
const hit=(a,b)=>a.left<b.right-.5&&b.left<a.right-.5&&a.top<b.bottom-.5&&b.top<a.bottom-.5;
for(const theme of ['stock','green','wall'])for(const mode of ['dark','light'])for(const w of [720,518,436,360])for(const alex of ['yes','off','no'])for(const name of ['short','long'])for(const choice of ['sands','react','alex']){
 Object.assign(S,{theme,mode,w,alex,name,choice});render();out.cases++;const tag=[theme,mode,w,alex,name,choice].join('/');
 for(const box of [document.getElementById('panel'),...document.querySelectorAll('.cell')]){
  const B=R(box),els=[...box.querySelectorAll(sel)].filter(e=>e.offsetParent!==null);
  els.forEach((a,i)=>{const ra=R(a);
   if(ra.right>B.right-15.5||ra.left<B.left+15.5)out.bad.push(tag+' overflow '+a.className);
   if(a.scrollWidth>a.clientWidth+1&&!a.classList.contains('ent'))out.bad.push(tag+' clipped '+a.className);
   els.slice(i+1).forEach(b=>{if(!a.contains(b)&&!b.contains(a)&&hit(ra,R(b)))out.bad.push(tag+' overlap '+a.className+' x '+b.className);});});
  for(const s of box.querySelectorAll('.sg')){const r=R(s);if(r.height<44)out.bad.push(tag+' choice height '+r.height);}
  for(const s of box.querySelectorAll('.strip')){const r=R(s);for(const p of s.children){const q=R(p);if(q.right>r.right-7||q.left<r.left+7||q.bottom>r.bottom-5)out.bad.push(tag+' strip child out');}}
  for(const g of box.querySelectorAll('.gh')){const r=R(g);if(r.width!==44||r.height!==44)out.bad.push(tag+' gh size');}}
 if(document.getElementById('contrast').textContent.includes('FAIL'))out.bad.push(tag+' contrast');
 if(theme==='stock'&&mode==='dark'&&choice==='alex'){const row=document.getElementById('row'),sg=row.querySelector('.seg');
  out.geo[[w,alex,name].join('/')]={content:R(document.getElementById('content')).width,stack:sg.classList.contains('stack'),seg:[R(sg).width,R(sg).height],row:R(row).height};}}
out.minContrast=(()=>{let m=[99,''];for(const th in TH)for(const md in TH[th])for(const p of pairs(TH[th][md])){const k=p[2]/p[1];if(k<m[0])m=[k,th+'/'+md+' '+p[0]+' '+p[2].toFixed(2)+' needs '+p[1]];}return m[1];})();
out.dash=/[\\u2013\\u2014]/.test(document.documentElement.outerHTML);
out.net=/https?:|src=|href=|@import|url\\(/.test(document.documentElement.outerHTML);
return JSON.stringify(out);})()`;
wv.connect('load-changed', (v, ev) => { if (ev !== WebKit.LoadEvent.FINISHED) return;
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => { wv.evaluate_javascript(CHECK, -1, null, null, null, (o, res) => {
    try { const r = wv.evaluate_javascript_finish(res); print(r.to_string()); } catch (e) { print('EVAL ERROR ' + e.message); }
    loop.quit(); }); return GLib.SOURCE_REMOVE; }); });
wv.load_uri(Gio.File.new_for_path(ARGV[0]).get_uri());
loop.run();
