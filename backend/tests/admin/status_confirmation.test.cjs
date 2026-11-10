const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {workspace,root} = require('./workspace.cjs');
test('confirmation is a real submit button with the value consumed by the handler',()=>{
  const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
  assert.match(html, /<button\b[^>]*type="submit"[^>]*value="confirm"[^>]*>Confirm update<\/button>/);
  assert.doesNotMatch(html, /<\/button\s+value=/);
});
test('opening and cancelling the modal never sends a status update',async()=>{
  const w=workspace(); w.open();
  assert.equal(w.element('#status-confirm').open,true);
  assert.match(w.element('#confirm-transition').textContent,/Submitted → Received/);
  await w.element('#status-confirm').close('cancel');
  assert.equal(w.requests.length,0);
});
test('confirm sends exactly one transition with its expected original status',async()=>{
  const w=workspace(); w.open();
  await w.element('#status-confirm').close('confirm');
  const updates=w.requests.filter(r=>r.options.method==='PATCH');
  assert.equal(updates.length,1);
  assert.equal(updates[0].url,'/api/v1/officer/cases/fictional-case/status');
  assert.deepEqual(JSON.parse(updates[0].options.body),{status:'received',expected_status:'submitted'});
  assert.match(w.element('#message').textContent,/Status updated to Received/);
  assert.equal(w.element('#sign-out').disabled,false);
});

test('an expired response from the previous session cannot sign out a new session', async()=>{
  let respond;
  const w=workspace(()=>new Promise(resolve=>{respond=resolve;}));
  const pending=vm.runInContext('api("/auth/me")',w.context);
  const rejected=assert.rejects(pending,/session changed/);
  vm.runInContext('token="new-session";',w.context);
  respond({status:401,ok:false});
  await rejected;
  assert.equal(vm.runInContext('token',w.context),'new-session');
});
test('a session switch while parsing a response discards the old response', async()=>{
  let parsed, started;
  const bodyStarted=new Promise(resolve=>{started=resolve;});
  const w=workspace(async()=>({status:200,ok:true,json:()=>{
    started(); return new Promise(resolve=>{parsed=resolve;});
  }}));
  const pending=vm.runInContext('api("/auth/me")',w.context);
  const rejected=assert.rejects(pending,/session changed/);
  await bodyStarted;
  vm.runInContext('token="new-session";',w.context);
  parsed({role:'admin'});
  await rejected;
  assert.equal(vm.runInContext('token',w.context),'new-session');
});
test('queue fetch requests one bounded page instead of traversing the dataset', async()=>{
  const w=workspace(async()=>({status:200,ok:true,json:async()=>({items:[],total:10000})}));
  await w.run('loadQueue()');
  assert.equal(w.requests.length,1);
  assert.match(w.requests[0].url,/limit=25&offset=0/);
});
