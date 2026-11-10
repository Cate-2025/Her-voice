'use strict';
let token = null, role = null, cases = [], selectedId = null, detailVersion = 0, saving = false;
const $ = selector => document.querySelector(selector);
const labels = { submitted: 'Submitted', received: 'Received', under_review: 'Under review', action_required: 'Action required', closed: 'Closed' };
const descriptions = {
  submitted: 'The report has reached the system. Receipt has not yet been acknowledged by an officer.',
  received: 'Acknowledge that an officer has received the report. This does not mean an investigation is complete.',
  under_review: 'Record that the report is being reviewed under the university process.',
  action_required: 'Record that follow-up is needed. The student receives a general status update. Share specific next steps through your approved communication process.',
  closed: 'Record that this case workflow is closed. Closure is not a finding of misconduct. Closed cases cannot be reopened.',
};
const transitions = { submitted: ['received'], received: ['under_review'], under_review: ['action_required', 'closed'], action_required: ['under_review'], closed: [] };
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[char]);
const stamp = item => new Date(item.submitted_at || item.created_at);
const dateLabel = date => date.toLocaleDateString('en-GB', { day:'numeric', month:'short', year:'numeric' });
const reference = item => item.case_code || String(item.id).split('-').pop().toUpperCase();
const title = item => `Report · ${dateLabel(stamp(item))} · ${reference(item)}`;
const timeLabel = item => stamp(item).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
const statusPill = status => `<span class="status ${labels[status] ? status : ''}">${escapeHtml(labels[status] || 'Unknown')}</span>`;
const message = (text = '', success = false) => { $('#message').textContent = text; $('#message').className = success ? 'success' : ''; };
function signOut() {
  token = null; role = null; detailVersion++;
  for (const controller of controllers) controller.abort();
  $('#status-confirm').onclose = null; $('#status-confirm').close();
  resetView();
  $('#dashboard').hidden = true; $('#login-panel').hidden = false;
  $('#case-detail').textContent = ''; $('#case-list').textContent = ''; $('#alert-list').textContent = '';
  $('#role-label').textContent = 'Authorised personnel'; $('#password').value = '';
  focus('#email');
}
async function request(path, options = {}, decode = 'json', timeoutMs = 20000) {
  const session = token, controller = new AbortController(); controllers.add(controller);
  let timer, timedOut = false;
  try {
    const work = (async () => {
      const response = await fetch(`/api/v1${path}`, {...options, signal:controller.signal,
        headers:{'Content-Type':'application/json', ...(session ? {Authorization:`Bearer ${session}`} : {}), ...(options.headers || {})}, cache:'no-store'});
      if (session !== token) throw new Error('Your session changed. Please sign in again.');
      if (response.status === 401) { signOut(); throw new Error(path === '/auth/login' ? 'Check your email and password.' : 'Your session expired. Please sign in again.'); }
      if (!response.ok) throw new Error(response.status === 409 ? 'This case has changed. Reload its details before choosing a status.' : response.status === 429 ? 'Too many attempts. Wait before trying again.' : 'The request could not complete. Please retry.');
      const result = response.status === 204 ? null : decode === 'blob' ? await response.blob() : await response.json();
      if (session !== token) throw new Error('Your session changed. Please sign in again.');
      return result;
    })();
    const timeout = new Promise((_, reject) => { timer = setTimeout(() => {
      timedOut = true; controller.abort(); reject(new Error('The request timed out. Check your connection and retry.'));
    }, timeoutMs); });
    return await Promise.race([work, timeout]);
  } catch (error) {
    if (session !== token) throw new Error('Your session changed. Please sign in again.');
    if (timedOut) throw new Error('The request timed out. Check your connection and retry.');
    if (error.name === 'AbortError') throw new Error('The request was interrupted. Please retry.');
    if (error instanceof TypeError) throw new Error('Unable to connect. Check your connection and retry.');
    throw error;
  } finally { clearTimeout(timer); controllers.delete(controller); }
}
const api = (path, options) => request(path, options);
$('#login-form').addEventListener('submit', async event => {
  event.preventDefault(); message(); $('#login-button').disabled = true;
  try {
    const session = token;
    const result = await api('/auth/login', {method:'POST', body:JSON.stringify({email:$('#email').value.trim(), password:$('#password').value})});
    if (token !== session) return;
    token = result.access_token;
    const user = await api('/auth/me');
    if (!['officer','admin'].includes(user.role)) { signOut(); throw new Error('Use an officer or administrator account.'); }
    role = user.role; $('#password').value = '';
    $('#role-label').textContent = role === 'admin' ? 'Administrator' : 'Officer';
    $('#login-panel').hidden = true; $('#dashboard').hidden = false;
    resetView(); emptyDetail(); focus('#queue-heading');
    await refresh();
  } catch (error) { message(error.message); }
  finally { $('#login-button').disabled = false; }
});
const PAGE_SIZE = 25;
let queueOffset = 0, queueTotal = 0, queueVersion = 0, queueBusy = false, queueLoaded = false;
let alertOffset = 0, alertTotal = 0, alertVersion = 0, alertBusy = false, alertItems = [];
let summaryVersion = 0, refreshing = false, relatedAlert = null;
let queueStamp = null, alertStamp = null, summaryStamp = null;
let uncertainId = null;
const controllers = new Set();
const focus = selector => $(selector)?.focus();
const updated = stamp => stamp ? `Last updated ${stamp.toLocaleString([], {day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}.` : 'Not loaded yet.';
function emptyDetail() {
  detailVersion++; selectedId = null;
  $('#case-detail').innerHTML = '<h2 id="detail-heading" tabindex="-1">Select a report</h2><p class="muted">Choose a report from the queue to read its details.</p>';
  syncSelection();
}
function setQueueBusy(value) {
  queueBusy = value;
  syncSelection();
  $('#case-list').setAttribute('aria-busy', String(value));
  $('#status-filter').disabled = value || saving;
  $('#clear-related').disabled = value || saving;
  $('#queue-prev').disabled = value || saving || queueOffset === 0;
  $('#queue-next').disabled = value || saving || queueOffset + PAGE_SIZE >= queueTotal;
}
function syncSelection() {
  document.querySelectorAll('.case').forEach(button => {
    button.setAttribute('aria-pressed', String(button.dataset.id === selectedId));
    button.disabled = saving || queueBusy;
  });
}
function renderQueue() {
  const active = document.activeElement;
  const focusedId = active?.classList?.contains('case') ? active.dataset.id : null;
  $('#queue-count').textContent = !queueLoaded ? 'Not loaded' : queueTotal ? `${queueOffset + 1}–${queueOffset + cases.length} of ${queueTotal}` : '0 reports';
  $('#case-list').innerHTML = cases.map(item => `<button class="case" data-id="${escapeHtml(item.id)}" aria-pressed="${item.id === selectedId}" ${saving ? 'disabled' : ''}><strong>${escapeHtml(title(item))}</strong><span class="small">Submitted at ${escapeHtml(timeLabel(item))}</span>${statusPill(item.status)}</button>`).join('') || (queueLoaded ? '<p class="muted">No reports match these filters.</p>' : '<p class="muted">Reports have not loaded.</p>');
  document.querySelectorAll('.case').forEach(button => {
    button.onclick = () => openCase(button.dataset.id, true);
    if (button.dataset.id === focusedId) button.focus();
  });
  if (focusedId && !cases.some(item => item.id === focusedId)) focus('#queue-heading');
  setQueueBusy(queueBusy);
}
function queuePath() {
  const params = new URLSearchParams({limit: PAGE_SIZE, offset: queueOffset});
  if ($('#status-filter').value) params.set('status_filter', $('#status-filter').value);
  if (relatedAlert) {
    params.set('staff_ref', relatedAlert.staff_ref);
    params.set('window_start', relatedAlert.window_start);
    params.set('window_end', relatedAlert.window_end);
  }
  return `/case-page?${params}`;
}
async function loadQueue({moveFocus = false} = {}) {
  const version = ++queueVersion, session = token;
  setQueueBusy(true); $('#queue-state').textContent = queueLoaded ? `Refreshing. ${updated(queueStamp)}` : 'Loading reports…';
  try {
    let result = await api(`/officer${queuePath()}`);
    if (session !== token || version !== queueVersion) return;
    // If concurrent changes emptied this page, return to the first page once.
    if (queueOffset && !result.items.length) {
      queueOffset = 0; result = await api(`/officer${queuePath()}`);
      if (session !== token || version !== queueVersion) return;
    }
    cases = result.items; queueTotal = result.total; queueLoaded = true; queueStamp = new Date();
    if (selectedId && !cases.some(item => item.id === selectedId)) emptyDetail();
    renderQueue(); $('#queue-state').textContent = updated(queueStamp);
    if (moveFocus) focus('#queue-heading');
  } catch (error) {
    if (session === token && version === queueVersion) $('#queue-state').textContent = `Reports could not refresh. ${updated(queueStamp)} ${queueLoaded ? 'Displayed reports may be out of date.' : ''} Use Refresh to retry.`;
  } finally { if (session === token && version === queueVersion) setQueueBusy(false); }
}
async function loadSummary() {
  const version = ++summaryVersion, session = token;
  $('#summary-state').textContent = 'Refreshing totals…';
  try {
    const result = await api('/officer/case-summary');
    if (session !== token || version !== summaryVersion) return;
    for (const [id, field] of [['total','total'],['new','submitted'],['review','under_review'],['alerts','alerts']]) $('#count-' + id).textContent = result[field];
    summaryStamp = new Date(); $('#summary-state').textContent = `All reports, across filters. ${updated(summaryStamp)}`;
  } catch (_) {
    if (session === token && version === summaryVersion) $('#summary-state').textContent = `Totals unavailable. ${updated(summaryStamp)} ${summaryStamp ? 'Displayed totals may be out of date.' : ''} Use Refresh to retry.`;
  }
}
function alertWindow(item) { return `${dateLabel(new Date(item.window_start))} – ${dateLabel(new Date(item.window_end))}`; }
function renderAlerts() {
  $('#alert-list').innerHTML = alertItems.map(item => `<article class="alert"><h3>${escapeHtml(item.staff_ref)}</h3><p>${escapeHtml(item.report_count)} distinct reporting accounts</p><p class="small">Recorded window: ${escapeHtml(alertWindow(item))}</p><button class="secondary related-reports" data-id="${escapeHtml(item.id)}">View reports in this window</button></article>`).join('') || '<p class="muted">No open review alerts.</p>';
  document.querySelectorAll('.related-reports').forEach(button => { button.onclick = () => {
    if (saving || queueBusy) return;
    relatedAlert = alertItems.find(item => item.id === button.dataset.id);
    $('#related-context').hidden = false;
    $('#related-label').textContent = `Reports for ${relatedAlert.staff_ref} · ${alertWindow(relatedAlert)}. Report count may differ from distinct accounts.`;
    $('#status-filter').value = ''; queueOffset = 0; queueTotal = 0; queueLoaded = false; queueStamp = null; cases = [];
    emptyDetail(); renderQueue(); void loadQueue({moveFocus: true});
  }; });
  $('#alert-range').textContent = alertTotal ? `${alertOffset + 1}–${alertOffset + alertItems.length} of ${alertTotal} open alerts` : '0 open alerts';
}
function setAlertBusy(value) {
  alertBusy = value; $('#alert-list').setAttribute('aria-busy', String(value));
  $('#alert-prev').disabled = value || saving || alertOffset === 0;
  $('#alert-next').disabled = value || saving || alertOffset + PAGE_SIZE >= alertTotal;
}
async function loadAlerts() {
  const version = ++alertVersion, session = token;
  setAlertBusy(true); $('#alert-state').textContent = 'Loading alerts…';
  try {
    let result = await api(`/officer/alert-page?limit=${PAGE_SIZE}&offset=${alertOffset}`);
    if (session !== token || version !== alertVersion) return;
    if (alertOffset && !result.items.length) {
      alertOffset = 0; result = await api(`/officer/alert-page?limit=${PAGE_SIZE}&offset=0`);
      if (session !== token || version !== alertVersion) return;
    }
    alertItems = result.items; alertTotal = result.total; renderAlerts(); alertStamp = new Date();
    $('#alert-state').textContent = updated(alertStamp);
  } catch (_) {
    if (session === token && version === alertVersion) $('#alert-state').textContent = `Alerts unavailable. ${updated(alertStamp)} ${alertStamp ? 'Displayed alerts may be out of date.' : ''} Use Refresh to retry.`;
  } finally { if (session === token && version === alertVersion) setAlertBusy(false); }
}
async function refresh() {
  if (saving || refreshing || !token) return;
  const session = token; refreshing = true; $('#refresh').disabled = true;
  try {
    await Promise.allSettled([loadQueue(), loadSummary(), loadAlerts()]);
    if (session === token && selectedId) await openCase(selectedId);
  } finally { if (session === token) { refreshing = false; $('#refresh').disabled = false; } }
}
function resetView() {
  queueVersion++; alertVersion++; summaryVersion++;
  queueOffset = 0; queueTotal = 0; queueLoaded = false; queueStamp = alertStamp = summaryStamp = null;
  alertOffset = 0; alertTotal = 0; alertItems = []; relatedAlert = null; uncertainId = null;
  cases = []; selectedId = null; saving = refreshing = false;
  $('#related-context').hidden = true; $('#status-filter').value = '';
  for (const id of ['total','new','review','alerts']) $('#count-' + id).textContent = '—';
  for (const id of ['summary-state','queue-state','alert-state']) $('#' + id).textContent = 'Not loaded yet.';
  setQueueBusy(false); setAlertBusy(false); $('#refresh').disabled = $('#sign-out').disabled = false;
}
function changePage(direction) {
  if (queueBusy || saving) return;
  queueOffset = Math.max(0, queueOffset + direction * PAGE_SIZE); emptyDetail(); void loadQueue({moveFocus:true});
}
$('#sign-out').onclick = () => { if (!saving) { signOut(); message(); } };
$('#refresh').onclick = () => refresh();
$('#status-filter').onchange = () => {
  queueOffset = 0; queueTotal = 0; queueLoaded = false; queueStamp = null; cases = []; emptyDetail(); renderQueue(); void loadQueue();
};
$('#clear-related').onclick = () => {
  relatedAlert = null; $('#related-context').hidden = true;
  $('#status-filter').value = ''; $('#status-filter').onchange(); focus('#status-filter');
};
$('#queue-prev').onclick = () => changePage(-1);
$('#queue-next').onclick = () => changePage(1);
for (const [id, direction] of [['alert-prev',-1],['alert-next',1]]) $('#' + id).onclick = () => {
  if (!alertBusy && !saving) { const session = token; alertOffset = Math.max(0, alertOffset + direction * PAGE_SIZE); void loadAlerts().then(() => { if (session === token) focus('#alerts-heading'); }); }
};
async function openCase(id, moveFocus = false, reconcile = false) {
  if (saving && !reconcile) return;
  const version = ++detailVersion;
  selectedId = id; syncSelection();
  $('#case-detail').innerHTML = '<p class="muted" role="status">Loading case…</p>';
  try {
    const item = await api(`/officer/cases/${encodeURIComponent(id)}`);
    if (version !== detailVersion || !token) return;
    if (uncertainId === id) uncertainId = null;
    const next = transitions[item.status] || [];
    const events = item.timeline.map(event => `<article class="event"><h3>${escapeHtml(new Date(event.occurred_at).toLocaleString())}</h3>${event.location_hint ? `<p class="small">${escapeHtml(event.location_hint)}</p>` : ''}<p>${escapeHtml(event.narrative)}</p></article>`).join('');
    $('#case-detail').innerHTML = `<div class="detail-heading"><div><h2 id="detail-heading" tabindex="-1">${escapeHtml(title(item))}</h2><p class="small">Submitted at ${escapeHtml(timeLabel(item))}</p></div>${statusPill(item.status)}</div>
      <p class="muted small">${escapeHtml(descriptions[item.status] || '')}</p>
      <div class="status-editor" id="status-editor"><h3>Next status</h3>${next.length ? `<label for="case-status">Choose the next step</label><select id="case-status"><option value="">Select a status…</option>${next.map(status => `<option value="${status}">${labels[status]}</option>`).join('')}</select><p id="status-description" class="status-description muted">Only valid next steps are available. Nothing changes until you confirm.</p><button id="update-status" disabled>Review status change</button>` : '<p class="muted">This case is closed. No further status changes are available.</p>'}</div>
      <dl class="facts"><div><dt>Person involved in the report</dt><dd>${escapeHtml(item.subject_staff_ref)}</dd></div><div><dt>Course or unit</dt><dd>${escapeHtml(item.course_ref || 'Not provided')}</dd></div></dl>
      <h3>Evidence</h3><div>${(item.evidence || []).filter(file => file.verification_status === 'verified').map(file => `<button class="secondary evidence-download" data-id="${escapeHtml(file.id)}" data-name="${escapeHtml(file.original_name)}">Download ${escapeHtml(file.original_name)} (${Math.ceil(file.byte_size / 1024)} KB)</button>`).join(' ') || '<p class="muted">No verified attachments.</p>'}</div><p class="small">Downloads are audited. File integrity and type are checked. Attachments have not been scanned for malware.</p>
      <h3>Incident timeline</h3>${events || '<p class="muted">No incident events available.</p>'}
      <details class="reference"><summary>Case reference</summary><code>${escapeHtml(item.id)}</code></details>
      ${role === 'admin' ? '<details class="reference"><summary>Controlled account identity access</summary><p>Only administrators can reveal the student’s account email. Every reveal requires a reason and is audited. Use this only when authorised for this case.</p><form id="identity-form" class="identity-form"><label>Reason for access<textarea id="identity-reason" minlength="10" maxlength="500" required placeholder="Explain why this access is necessary"></textarea></label><button id="identity-button">Reveal account email</button></form><div id="identity-result" aria-live="polite"></div></details>' : '<p class="notice">Student account identity is hidden from officers. Information in the report itself may still identify someone.</p>'}`;
    if (moveFocus) focus('#detail-heading');
    document.querySelectorAll('.evidence-download').forEach(button => { button.onclick = async () => {
      button.disabled = true;
      try {
        const blob = await request(`/evidence/${encodeURIComponent(button.dataset.id)}/file`, {}, 'blob', 60000);
        if (version !== detailVersion || !token) return;
        const url = URL.createObjectURL(blob), link = document.createElement('a');
        link.href = url; link.download = button.dataset.name; link.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
      } catch (error) { if (version === detailVersion && token) message(error.message); }
      finally { if (button.isConnected) button.disabled = false; }
    }; });
    if (next.length && uncertainId !== id) {
      $('#case-status').disabled = saving;
      $('#case-status').onchange = () => {
        $('#status-description').textContent = descriptions[$('#case-status').value] || 'Only valid next steps are available. Nothing changes until you confirm.';
        $('#update-status').disabled = !$('#case-status').value;
      };
      $('#update-status').onclick = event => confirmStatus(item, $('#case-status').value, event);
    }
    if (role === 'admin') $('#identity-form').onsubmit = async event => {
      event.preventDefault(); const button = $('#identity-button'); button.disabled = true;
      try {
        const identity = await api(`/officer/cases/${encodeURIComponent(id)}/reporter-identity`, {method:'POST', body:JSON.stringify({reason:$('#identity-reason').value.trim()})});
        if (version !== detailVersion || !token) return;
        $('#identity-result').textContent = `Account email: ${identity.email}`; $('#identity-result').className = 'identity-value';
        $('#identity-reason').value = ''; message('Identity access recorded in the audit log.', true);
      } catch (error) { if (version === detailVersion && token) message(error.message); }
      finally { if (button.isConnected) button.disabled = false; }
    };
  } catch (error) { if (version === detailVersion && token) { $('#case-detail').innerHTML = '<h2 id="detail-heading" tabindex="-1">Case unavailable</h2><p>Choose this report again to retry. Its status has not been confirmed here.</p>'; message(error.message); if (moveFocus) focus('#detail-heading'); } }
}
function confirmStatus(item, target, activation) {
  if (!target || saving || uncertainId === item.id) return;
  if (queueBusy || refreshing) { message('Wait for the reports to finish refreshing, then review the status change.'); return; }
  const dialog = $('#status-confirm'); dialog.returnValue = '';
  // Keyboard/programmatic activation remains immediate, including after a pointer opening.
  dialog.setAttribute('data-pointer-motion', String(Boolean(activation?.detail > 0)));
  $('#confirm-transition').textContent = `${title(item)}: ${labels[item.status]} → ${labels[target]}`;
  $('#confirm-description').textContent = descriptions[target];
  dialog.onclose = async () => {
    if (dialog.returnValue !== 'confirm') { focus('#update-status'); return; }
    const session = token;
    saving = true; syncSelection(); setQueueBusy(queueBusy); setAlertBusy(alertBusy);
    $('#update-status').disabled = true; $('#refresh').disabled = true; $('#sign-out').disabled = true;
    message('Updating case status…');
    try {
      await api(`/officer/cases/${encodeURIComponent(item.id)}/status`, {method:'PATCH', body:JSON.stringify({status:target, expected_status:item.status})});
      if (session !== token) return;
      message(`Status updated to ${labels[target]}. A neutral student update was created.`, true);
    } catch (error) {
      if (session !== token) return;
      uncertainId = item.id;
      message('The update could not be confirmed. Its current status will be checked; do not submit the change again until it has loaded.');
    } finally {
      if (session === token) {
        // Read the case before enabling another mutation; never auto-resend PATCH.
        const wasUncertain = uncertainId === item.id;
        await openCase(item.id, true, true);
        if (session !== token) return;
        if (wasUncertain && uncertainId === null && session === token) message('The case status has been reloaded. Check the current status before deciding whether another change is needed.');
        await Promise.allSettled([loadQueue(), loadSummary(), loadAlerts()]);
        if (session !== token) return;
        saving = false;
        $('#refresh').disabled = false; $('#sign-out').disabled = false;
        if ($('#case-status')) $('#case-status').disabled = false;
        syncSelection(); setQueueBusy(queueBusy); setAlertBusy(alertBusy);
        if (selectedId) focus('#detail-heading'); else focus('#queue-heading');
      }
    }
  };
  dialog.showModal();
}
