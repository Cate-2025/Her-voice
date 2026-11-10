const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '../../app/static/admin');
const report = {id:'11111111-1111-1111-1111-111111111111', status:'submitted', submitted_at:'2026-11-10T10:15:00Z', subject_staff_ref:'Fictional subject', timeline:[], evidence:[]};
function workspace(fetcher, {timerCap} = {}) {
  const elements = new Map(), requests = [], buttons = [];
  const document = {activeElement:null, querySelector:element, querySelectorAll:selector=>selector === '.case' ? buttons : []};
  function element(id) {
    if (!elements.has(id)) elements.set(id, {textContent:'', value:'', className:'', innerHTML:'', dataset:{}, disabled:false, hidden:false,
      classList:{contains:()=>false}, setAttribute(name,value){this[name]=value;},
      focus(){document.activeElement=this;},
      addEventListener(type, handler){this[type]=handler;},
      close(value=''){this.open=false; this.returnValue=value; return this.onclose?.();},
      showModal(){this.open=true;}});
    return elements.get(id);
  }
  const context = vm.createContext({document, AbortController, URLSearchParams, clearTimeout,
    fetch:async(url, options={})=>{
      requests.push({url,options});
      if (fetcher) return fetcher(url,options);
      const body = url.includes('case-summary') ? {total:0,submitted:0,under_review:0,alerts:0}
        : url.includes('case-page') || url.includes('alert-page') ? {items:[],total:0} : report;
      return {ok:true,status:200,json:async()=>body};
    },console,setTimeout:timerCap ? (fn,ms)=>setTimeout(fn,Math.min(ms,timerCap)) : setTimeout});
  vm.runInContext(fs.readFileSync(path.join(root,'app.js'),'utf8'),context);
  vm.runInContext('token="fixture-token";',context);
  const run = source => vm.runInContext(source,context);
  const open = () => run("confirmStatus({id:'fictional-case',status:'submitted',created_at:'2026-10-01T12:00:00Z'},'received')");
  return {element,requests,open,context,run,buttons,document};
}
module.exports={workspace,root,report};
