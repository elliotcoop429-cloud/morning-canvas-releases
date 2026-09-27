'use strict';
const $ = id => document.getElementById(id);
let layout, defaults, etag, saved, selected = 'title', history = [], future = [], scale = 1, preview = false, drag = null, busy = false;
const symbols = {text:'T',dynamic:'◷',button:'▣',classes:'☷',tabs:'▤',content:'▦',rule:'─'};
const clone = x => JSON.parse(JSON.stringify(x));
const current = () => layout.items.find(x => x.id === selected);
const dirty = () => JSON.stringify(layout) !== saved;
const editableText = x => x.kind === 'text' || x.kind === 'button';
const labelStyle = x => ['text','dynamic'].includes(x.kind);
function message(text, error=false) { $('message').textContent = text; $('message').classList.toggle('error',error); }
function checkpoint() { history.push(JSON.stringify(layout)); if(history.length>100) history.shift(); future=[]; }
function state() { $('save-state').textContent = dirty() ? 'Unsaved changes' : 'All changes saved'; $('save').disabled = busy || !dirty(); $('undo').disabled = !history.length; $('redo').disabled = !future.length; }
function el(tag, cls, text) { const node=document.createElement(tag); if(cls)node.className=cls; if(text!==undefined)node.textContent=text; return node; }
function constrain(x) { x.width=Math.max(1,Math.min(1040,Number(x.width)||1)); x.height=Math.max(1,Math.min(660,Number(x.height)||1)); x.x=Math.max(0,Math.min(1040-x.width,Number(x.x)||0)); x.y=Math.max(0,Math.min(660-x.height,Number(x.y)||0)); x.fontSize=Math.max(8,Math.min(72,Number(x.fontSize)||13)); }
function valid(data) {
 if(!data || data.version!==1 || data.width!==1040 || data.height!==660 || !Array.isArray(data.items) || data.items.length>100) return false;
 const seen=new Set(), specs=new Map(defaults.items.map(x=>[x.id,x]));
 for(const x of data.items) {
  if(!x || Object.keys(x).sort().join()!==Object.keys(defaults.items[0]).sort().join() || typeof x.id!=='string' || seen.has(x.id))return false;
  seen.add(x.id); const spec=specs.get(x.id);
  if(spec ? x.kind!==spec.kind : (!/^custom_[a-zA-Z0-9_-]{1,64}$/.test(x.id)||x.kind!=='text'))return false;
  if(typeof x.name!=='string'||x.name.length>80||typeof x.text!=='string'||x.text.length>500||typeof x.visible!=='boolean'||typeof x.color!=='string'||(x.color!==''&&!/^#[\da-f]{6}$/i.test(x.color)))return false;
  if(!['x','y','width','height','fontSize'].every(k=>typeof x[k]==='number'&&Number.isFinite(x[k])))return false;
  if(x.x<0||x.y<0||x.width<1||x.height<1||x.x+x.width>1040||x.y+x.height>660||x.fontSize<8||x.fontSize>72)return false;
 }
 return defaults.items.every(x=>seen.has(x.id));
}
function panel(x) {
 const inner=el('div','panel-inner'); const base=defaults.items.find(y=>y.id===x.id);
 inner.style.width=base.width+'px'; inner.style.height=base.height+'px'; inner.style.transform=`scale(${x.width/base.width},${x.height/base.height})`;
 if(x.kind==='classes') ['All classes','English Literature','Biology','Algebra II','World History'].forEach(name=>{const row=el('div','class-row');row.append(el('span','dot'),el('span','',name));inner.append(row);});
 if(x.kind==='tabs') ['Announcements','Grades','Calendar','Tests','To-do','Submitted','Weekly Overview'].forEach(t=>inner.append(el('span','tab'+(t==='To-do'?' active':''),t)));
 if(x.kind==='content') {
  const body=el('div','sample-content');body.append(el('h3','','Your to-do list'),el('div','subtitle','A little progress, every day.  ·  3 upcoming assignments'));
  [['Read chapter 4','English Literature · 10 points','Tomorrow'],['Cell structure worksheet','Biology · 20 points','Tuesday'],['Practice: quadratic equations','Algebra II · 15 points','Wednesday']].forEach(([title,desc,date])=>{const row=el('div','task-card'),copy=el('div');copy.append(el('strong','',title),el('small','',desc));row.append(el('div','check'),copy,el('em','',date));body.append(row);});inner.append(body);
 }
 return inner;
}
function renderCanvas() {
 $('canvas').replaceChildren(); $('canvas').classList.toggle('preview-mode',preview);
 for(const x of layout.items) {
  const node=el('div',`object ${x.kind} ${x.id}${selected===x.id?' selected':''}${x.visible?'':' hidden'}`);
  node.dataset.object=x.id;node.setAttribute('aria-label',x.name);node.style.cssText=`left:${x.x}px;top:${x.y}px;width:${x.width}px;height:${x.height}px;font-size:${x.fontSize}px;`;
  if(x.color && labelStyle(x))node.style.color=x.color;
  if(['classes','tabs','content'].includes(x.kind))node.append(panel(x));else if(x.kind!=='rule')node.append(document.createTextNode(x.text));
  if(selected===x.id && !preview){const handle=el('span','resize-handle');handle.dataset.resize='true';handle.setAttribute('aria-label','Resize '+x.name);node.append(handle);}
  node.addEventListener('pointerdown',event=>{
   if(preview||event.button!==0)return;event.preventDefault();event.stopPropagation();selected=x.id;
   drag={startX:event.clientX,startY:event.clientY,initial:clone(x),before:JSON.stringify(layout),resize:!!event.target.dataset.resize};
   render();$('canvas').focus();$('canvas').setPointerCapture(event.pointerId);
  });
  $('canvas').append(node);
 }
}
function renderTree(){
 $('tree').replaceChildren();$('count').textContent=layout.items.length;
 for(const x of layout.items){const row=el('button',`tree-item${x.id===selected?' selected':''}${x.visible?'':' hidden'}`);row.setAttribute('role','treeitem');row.setAttribute('aria-selected',String(x.id===selected));row.append(el('span','glyph',symbols[x.kind]),el('span','',x.name));row.addEventListener('click',()=>{selected=x.id;render();});$('tree').append(row);}
}
function property(grid, text, key, type='number', wide=false) {
 const x=current(),label=el('label','prop'+(wide?' wide':''),text),input=el('input');input.type=type;input.setAttribute('aria-label',text);
 input.value=type==='color'?(x[key]||'#23354b'):x[key];if(type==='number'){input.step=1;input.min=key==='fontSize'?8:0;input.max=key==='fontSize'?72:(['y','height'].includes(key)?660:1040);}
 if(type==='text')input.maxLength=key==='name'?80:500;
 let editing=false;
 input.addEventListener('input',()=>{if(type==='number' && input.value==='')return;if(!editing){checkpoint();editing=true;}x[key]=type==='number'?Number(input.value):input.value;constrain(x);renderCanvas();renderTree();state();});
 input.addEventListener('change',()=>{editing=false;renderProperties();});label.append(input);grid.append(label);
}
function renderProperties(){
 const box=$('properties');box.replaceChildren();const x=current();
 if(!x){box.append(el('p','empty','Select an object on the canvas or in Explorer to edit its properties.'));return;}
 box.append(el('div','selection-name',x.name),el('div','selection-kind',x.id.startsWith('custom_')?'Custom text label':`Dashboard · ${x.kind}`));
 const grid=el('div','prop-grid');property(grid,'Name','name','text',true);property(grid,'X','x');property(grid,'Y','y');property(grid,'Width','width');property(grid,'Height','height');
 if(editableText(x))property(grid,'Text','text','text',true);
 if(labelStyle(x)||x.kind==='button')property(grid,'Font size','fontSize');
 if(labelStyle(x))property(grid,'Text color','color','color');
 box.append(grid);
 if(x.kind==='dynamic')box.append(el('p','empty','The app supplies this text automatically.'));
 if(['classes','tabs','content'].includes(x.kind))box.append(el('p','empty','Resize scales this whole panel. Individual school rows and dialogs remain in the app’s code.'));
 const vis=el('label','visibility'),check=el('input');check.type='checkbox';check.checked=x.visible;check.addEventListener('change',()=>{checkpoint();x.visible=check.checked;render();});vis.append(check,document.createTextNode('Visible in the app'));box.append(vis);
 if(labelStyle(x)){const color=el('button','property-action','Use app text color');color.addEventListener('click',()=>{checkpoint();x.color='';render();});box.append(color);}
 const reset=el('button','property-action',x.id.startsWith('custom_')?'Remove text label':'Reset this object');reset.addEventListener('click',()=>{checkpoint();const i=layout.items.indexOf(x),def=defaults.items.find(y=>y.id===x.id);if(def)layout.items[i]=clone(def);else{layout.items.splice(i,1);selected='title';}render();});box.append(reset);
}
function render(){renderCanvas();renderTree();renderProperties();state();}
function fit(){if(!layout)return;scale=$('zoom').value==='fit'?Math.min(($('viewport').clientWidth-48)/1040,($('viewport').clientHeight-56)/660):Number($('zoom').value);scale=Math.max(.2,scale);$('canvas').style.transform=`scale(${scale})`;$('canvas-wrap').style.width=1040*scale+'px';$('canvas-wrap').style.height=660*scale+'px';}
$('canvas').addEventListener('pointermove',event=>{
 if(!drag)return;const x=current(),snap=$('snap').checked?4:1,round=n=>Math.round(n/snap)*snap,dx=(event.clientX-drag.startX)/scale,dy=(event.clientY-drag.startY)/scale;
 if(drag.resize){x.width=Math.min(1040-x.x,Math.max(1,round(drag.initial.width+dx)));x.height=Math.min(660-x.y,Math.max(1,round(drag.initial.height+dy)));}else{x.x=round(drag.initial.x+dx);x.y=round(drag.initial.y+dy);constrain(x);}
 renderCanvas();renderProperties();state();
});
function finishDrag(){if(!drag)return;if(drag.before!==JSON.stringify(layout)){history.push(drag.before);future=[];}drag=null;state();}
$('canvas').addEventListener('pointerup',finishDrag);$('canvas').addEventListener('pointercancel',finishDrag);
$('undo').onclick=()=>{if(!history.length)return;future.push(JSON.stringify(layout));layout=JSON.parse(history.pop());render();};
$('redo').onclick=()=>{if(!future.length)return;history.push(JSON.stringify(layout));layout=JSON.parse(future.pop());render();};
$('insert').onclick=()=>{if(layout.items.length>=100)return message('The canvas can hold up to 100 objects.',true);checkpoint();const x={id:'custom_'+crypto.randomUUID(),name:'Text label',kind:'text',x:320,y:560,width:260,height:36,text:'Make today a good day.',fontSize:18,color:'',visible:true};layout.items.push(x);selected=x.id;render();};
$('preview').onclick=()=>{preview=!preview;$('preview').setAttribute('aria-pressed',String(preview));$('preview').textContent=preview?'✎ Edit layout':'▷ Preview';$('hint').textContent=preview?'Visual preview · Sample data · App actions run in the Mac app.':'Select an object, then drag to move. Pull the corner to resize. Arrow keys nudge.';renderCanvas();};
$('fit').onclick=()=>{$('zoom').value='fit';fit();};$('zoom').onchange=fit;new ResizeObserver(fit).observe($('viewport'));
async function readSaved(){const response=await fetch('/api/layout');if(!response.ok)throw Error('Unable to read the saved layout.');const data=await response.json();if(!valid(data))throw Error('The saved layout is invalid. Check Resources/gui-layout.json.');return {data,tag:response.headers.get('ETag')};}
async function load(){try{const {data,tag}=await readSaved();layout=data;etag=tag;saved=JSON.stringify(layout);history=[];future=[];render();fit();message('Layout loaded. Select anything to start designing.');}catch(e){message(e.message,true);}}
$('save').onclick=async()=>{if(busy)return;busy=true;state();const draft=JSON.stringify(layout);try{const response=await fetch('/api/layout',{method:'PUT',headers:{'Content-Type':'application/json','X-Morning-Canvas-Editor':'1','If-Match':etag},body:draft});const result=await response.json();if(!response.ok)throw Error(result.error);etag=response.headers.get('ETag');saved=draft;message('Saved to your project. Rebuild the Mac app to use this layout.');}catch(e){message(e.message,true);}finally{busy=false;state();}};
$('reload').onclick=()=>{if(!dirty())return load();$('confirm').showModal();};$('cancel-confirm').onclick=()=>$('confirm').close();$('accept-confirm').onclick=()=>{$('confirm').close();load();};
$('export').onclick=()=>{const url=URL.createObjectURL(new Blob([JSON.stringify(layout,null,2)+'\n'],{type:'application/json'}));const a=el('a');a.href=url;a.download='gui-layout.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);message('Draft exported.');};
$('import').onchange=async event=>{try{const file=event.target.files[0];if(!file)return;if(file.size>128000)throw Error('Layout file is too large.');const data=JSON.parse(await file.text());if(!valid(data))throw Error('That file is not a valid Morning Canvas layout.');checkpoint();layout=data;render();message('Imported as an unsaved draft. Save layout to apply it.');}catch(e){message(e.message,true);}finally{event.target.value='';}};
window.addEventListener('keydown',event=>{
 if(!layout)return;const input=['INPUT','SELECT','TEXTAREA'].includes(event.target.tagName);
 if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='s'){event.preventDefault();if(!$('save').disabled)$('save').click();}
 if(input||$('confirm').open)return;
 if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='z'){event.preventDefault();$(event.shiftKey?'redo':'undo').click();return;}
 const x=current();if(!preview&&x&&['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.key)){event.preventDefault();checkpoint();const step=event.shiftKey?10:1;x.x+=event.key==='ArrowLeft'?-step:event.key==='ArrowRight'?step:0;x.y+=event.key==='ArrowUp'?-step:event.key==='ArrowDown'?step:0;constrain(x);render();}
});
window.addEventListener('beforeunload',event=>{if(layout&&dirty()){event.preventDefault();event.returnValue='';}});
(async()=>{try{defaults=await (await fetch('/default-layout.json')).json();await load();setInterval(async()=>{if(!layout||busy||drag)return;try{const {data,tag}=await readSaved();if(tag===etag)return;if(dirty()){message('A newer layout was saved. Export your draft, then Reload saved before continuing.',true);return;}layout=data;etag=tag;saved=JSON.stringify(data);history=[];future=[];render();message('Loaded your collaborator’s saved changes.');}catch{/* Keep local work when disconnected. */}},4000);}catch(e){message('Could not open Studio: '+e.message,true);}})();
