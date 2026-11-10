const {test} = require('node:test');
const assert = require('node:assert/strict');
const {workspace,report} = require('./workspace.cjs');
const json = value => ({status:200,ok:true,json:async()=>value});
const tick = () => new Promise(resolve=>setImmediate(resolve));

test('request timeout ends even when fetch ignores abort', async()=>{
  const w=workspace(()=>new Promise(()=>{}));
  await assert.rejects(w.run('request("/fixture", {}, "json", 5)'),/timed out/);
  assert.equal(w.run('controllers.size'),0);
});
test('timeout includes stalled body parsing', async()=>{
  const w=workspace(async()=>({status:200,ok:true,json:()=>new Promise(()=>{})}));
  await assert.rejects(w.run('request("/fixture", {}, "json", 5)'),/timed out/);
});
test('same-minute cases receive different visible references', ()=>{
  const w=workspace();
  assert.notEqual(w.run(`title(${JSON.stringify(report)})`),w.run(`title(${JSON.stringify({...report,id:'22222222-2222-2222-2222-222222222222'})})`));
});
test('opening a report preserves queue controls and moves focus to details', async()=>{
  const w=workspace();
  w.element('#case-list').innerHTML='Existing queue buttons';
  const button={dataset:{id:report.id},setAttribute(name,value){this[name]=value;}};w.buttons.push(button);
  await w.run(`openCase('${report.id}',true)`);
  assert.equal(w.element('#case-list').innerHTML,'Existing queue buttons');
  assert.equal(button['aria-pressed'],'true');
  assert.equal(w.document.activeElement,w.element('#detail-heading'));
});
test('filter changes clear old actionable details before requesting new page', async()=>{
  const w=workspace();
  w.run(`selectedId='old';queueOffset=50;`);
  w.element('#case-detail').innerHTML='Old actionable report';
  w.element('#status-filter').value='closed';w.element('#status-filter').onchange();
  assert.equal(w.run('selectedId'),null);
  assert.equal(w.run('queueOffset'),0);
  assert.doesNotMatch(w.element('#case-detail').innerHTML,/Old actionable/);
  await tick();
  assert.match(w.requests[0].url,/status_filter=closed/);
});
test('queue recovers independently of alerts failure and global totals are not page length', async()=>{
  const w=workspace(async url=>{
    if(url.includes('alert-page'))throw Error('Fixture offline');
    if(url.includes('case-summary'))return json({total:123,submitted:100,under_review:23,alerts:2});
    return json({items:[report],total:123});
  });
  await w.run('refresh()');
  assert.equal(w.element('#count-total').textContent,123);
  assert.match(w.element('#case-list').innerHTML,/Report/);
  assert.match(w.element('#alert-state').textContent,/unavailable/);
  assert.match(w.element('#queue-state').textContent,/Last updated/);
});
test('failed refresh explicitly marks retained totals and rows stale', async()=>{
  const w=workspace(async()=>{throw Error('Fixture offline');});
  w.run('queueLoaded=true;queueStamp=summaryStamp=new Date();');
  w.element('#count-total').textContent='12';w.element('#case-list').innerHTML='Old rows';
  await w.run('refresh()');
  assert.equal(w.element('#count-total').textContent,'12');
  assert.equal(w.element('#case-list').innerHTML,'Old rows');
  assert.match(w.element('#queue-state').textContent,/out of date/);
  assert.match(w.element('#summary-state').textContent,/out of date/);
});
test('timed-out mutation is not resent; fresh detail read reconciles state', async()=>{
  const w=workspace(async(url,options)=>{
    if(options.method==='PATCH')return new Promise(()=>{});
    if(url.includes('/cases/'))return json({...report,id:'fictional-case',status:'received'});
    if(url.includes('case-summary'))return json({total:1,submitted:0,under_review:0,alerts:0});
    if(url.includes('case-page'))return json({items:[{...report,id:'fictional-case',status:'received'}],total:1});
    return json({items:[],total:0});
  },{timerCap:5});
  w.open();await w.element('#status-confirm').close('confirm');
  assert.equal(w.requests.filter(r=>r.options.method==='PATCH').length,1);
  assert.equal(w.run('uncertainId'),null);
  assert.equal(w.run('saving'),false);
  assert.equal(w.element('#sign-out').disabled,false);
  assert.match(w.element('#case-detail').innerHTML,/Received/);
  assert.doesNotMatch(w.element('#message').textContent,/Status updated/);
});
test('confirmed mutation feedback survives failed queue refresh', async()=>{
  const w=workspace(async(url,options)=>{
    if(options.method==='PATCH')return json({...report,id:'fictional-case',status:'received'});
    if(url.includes('/cases/'))return json({...report,id:'fictional-case',status:'received'});
    throw Error('Fixture refresh failure');
  });
  w.open();await w.element('#status-confirm').close('confirm');
  assert.match(w.element('#message').textContent,/Status updated to Received/);
  assert.match(w.element('#queue-state').textContent,/could not refresh/);
});
test('unreconciled mutation shows no status editor to submit again', async()=>{
  const w=workspace(async()=>{throw Error('Fixture offline');});
  w.open();await w.element('#status-confirm').close('confirm');
  assert.equal(w.run('uncertainId'),'fictional-case');
  assert.match(w.element('#case-detail').innerHTML,/Case unavailable/);
  assert.doesNotMatch(w.element('#case-detail').innerHTML,/id="update-status"/);
});
test('late refresh cannot overwrite signed-out data', async()=>{
  let resolve;
  const w=workspace(()=>new Promise(r=>{resolve=r;}));
  const pending=w.run('loadQueue()');w.run('signOut()');
  resolve(json({items:[report],total:1}));await pending;
  assert.equal(w.element('#case-list').innerHTML,'');
  assert.equal(w.element('#count-total').textContent,'—');
});
test('alert drill-through uses exact reference and recorded dates, without a review mutation', async()=>{
  const w=workspace();
  const alert={id:'alert-one',staff_ref:'Staff & One',window_start:'2026-08-12T10:00:00Z',window_end:'2026-11-10T10:00:00Z'};
  w.run(`alertItems=[${JSON.stringify(alert)}];alertTotal=1;`);
  const button={dataset:{id:alert.id}};
  const base=w.document.querySelectorAll;
  w.document.querySelectorAll=selector=>selector==='.related-reports'?[button]:base(selector);
  w.run('renderAlerts()');
  button.onclick();await tick();
  assert.equal(w.element('#related-context').hidden,false);
  const query=new URL(w.requests[0].url,'http://fixture').searchParams;
  assert.equal(query.get('staff_ref'),alert.staff_ref);
  assert.equal(query.get('window_start'),alert.window_start);
  assert.equal(query.get('window_end'),alert.window_end);
  assert.equal(w.requests.filter(r=>r.options.method==='POST').length,0);
});
test('paging asks for the next bounded slice and clears the previous selection', async()=>{
  const w=workspace();w.run('queueTotal=80;selectedId="old";');
  w.element('#queue-next').onclick();await tick();
  assert.match(w.requests[0].url,/limit=25&offset=25/);
  assert.equal(w.run('selectedId'),null);
});
test('cancelling confirmation returns focus to its action', async()=>{
  const w=workspace();w.open();await w.element('#status-confirm').close('cancel');
  assert.equal(w.document.activeElement,w.element('#update-status'));
  assert.equal(w.requests.length,0);
});
test('another transition stays blocked while the first is being reconciled', async()=>{
  let resolveDetails, started;
  const reading=new Promise(resolve=>{started=resolve;});
  const w=workspace(async(url,options)=>{
    if(options.method==='PATCH')return json({...report,id:'fictional-case',status:'received'});
    if(url.includes('/cases/')){started();return new Promise(resolve=>{resolveDetails=resolve;});}
    if(url.includes('case-summary'))return json({total:1,submitted:0,under_review:0,alerts:0});
    return json({items:[],total:0});
  });
  w.open();const pending=w.element('#status-confirm').close('confirm');await reading;
  assert.equal(w.run('saving'),true);
  w.run(`confirmStatus({id:'other',status:'submitted',created_at:'2026-11-10T00:00:00Z'},'received')`);
  assert.equal(w.element('#status-confirm').open,false);
  resolveDetails(json({...report,id:'fictional-case',status:'received'}));await pending;
  assert.equal(w.requests.filter(r=>r.options.method==='PATCH').length,1);
  assert.equal(w.run('saving'),false);
});
test('pointer opening enables only the confirmation entrance treatment', ()=>{
  const w=workspace();
  w.run(`confirmStatus({id:'fixture',status:'submitted',created_at:'2026-11-10T00:00:00Z'},'received',{detail:1})`);
  assert.equal(w.element('#status-confirm')['data-pointer-motion'],'true');
  assert.equal(w.element('#status-confirm').open,true);
  assert.equal(w.requests.length,0);
});
test('keyboard opening resets the previous pointer motion treatment', async()=>{
  const w=workspace();
  w.run(`confirmStatus({id:'fixture',status:'submitted',created_at:'2026-11-10T00:00:00Z'},'received',{detail:1})`);
  await w.element('#status-confirm').close('cancel');
  w.run(`confirmStatus({id:'fixture',status:'submitted',created_at:'2026-11-10T00:00:00Z'},'received',{detail:0})`);
  assert.equal(w.element('#status-confirm')['data-pointer-motion'],'false');
  assert.equal(w.element('#status-confirm').open,true);
});
test('programmatic opening is immediate and cancellation restores focus', async()=>{
  const w=workspace();w.open();
  assert.equal(w.element('#status-confirm')['data-pointer-motion'],'false');
  await w.element('#status-confirm').close('cancel');
  assert.equal(w.document.activeElement,w.element('#update-status'));
  assert.equal(w.requests.length,0);
});
