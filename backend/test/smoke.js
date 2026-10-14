'use strict';

/**
 * End-to-end smoke test for the HERVOICE backend.
 *
 * Run with:  node test/smoke.js
 *
 * The script boots the API on a throwaway port, exercises the flows that the
 * Flutter client depends on (registration, reporting pathways, evidence vault,
 * offline batch sync, case tracking, pattern detection, institutional
 * dashboard) and prints a PASS/FAIL summary. It uses an isolated data
 * directory so it never touches demonstration data.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'hervoice-smoke-'));

// The store resolves paths relative to backend/, so the existing data folder is
// moved aside for the duration of the run and restored afterwards.
const backendRoot = path.join(__dirname, '..');
const dataDir = path.join(backendRoot, 'data');
const uploadsDir = path.join(backendRoot, 'uploads');
const backupDir = path.join(tmpRoot, 'previous');

if (fs.existsSync(dataDir) || fs.existsSync(uploadsDir)) {
  fs.mkdirSync(backupDir, { recursive: true });
  if (fs.existsSync(dataDir)) fs.renameSync(dataDir, path.join(backupDir, 'data'));
  if (fs.existsSync(uploadsDir)) fs.renameSync(uploadsDir, path.join(backupDir, 'uploads'));
}

process.env.JWT_SECRET = 'smoke_test_secret';
process.env.ADMIN_EMAILS = 'admin@university.example';
process.env.OFFICER_EMAILS = 'officer@university.example';

const app = require('../index');

const PORT = 4999;
const BASE = `http://127.0.0.1:${PORT}/api`;

const results = [];

function check(name, condition, detail = '') {
  results.push({ name, ok: Boolean(condition), detail });
  console.log(`${condition ? 'PASS' : 'FAIL'}  ${name}${detail ? ` - ${detail}` : ''}`);
}

async function call(method, route, { token, body } = {}) {
  const response = await fetch(`${BASE}${route}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch (err) {
    json = { raw: text };
  }
  return { status: response.status, body: json };
}

function restore() {
  try {
    fs.rmSync(dataDir, { recursive: true, force: true });
    fs.rmSync(uploadsDir, { recursive: true, force: true });
    const previousData = path.join(backupDir, 'data');
    const previousUploads = path.join(backupDir, 'uploads');
    if (fs.existsSync(previousData)) fs.renameSync(previousData, dataDir);
    if (fs.existsSync(previousUploads)) fs.renameSync(previousUploads, uploadsDir);
  } catch (err) {
    console.warn('Cleanup warning:', err.message);
  }
}

async function main() {
  const server = app.listen(PORT, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));

  try {
    // --- Health and vocabulary ------------------------------------------
    const health = await call('GET', '/health');
    check('health endpoint responds', health.status === 200 && health.body.status === 'ok');

    const meta = await call('GET', '/meta');
    check('meta exposes the three reporting pathways',
      meta.status === 200 && meta.body.reportingTypes.length === 3);

    // --- Accounts --------------------------------------------------------
    const studentEmail = `sarah.${Date.now()}@student.example`;
    const registered = await call('POST', '/auth/register', {
      body: { email: studentEmail, password: 'StrongPass123', displayName: 'Sarah' },
    });
    check('student registration succeeds', registered.status === 201);

    const weakPassword = await call('POST', '/auth/register', {
      body: { email: `weak.${Date.now()}@student.example`, password: 'short' },
    });
    check('weak password is rejected', weakPassword.status === 400, weakPassword.body.message);

    const studentLogin = await call('POST', '/auth/login', {
      body: { email: studentEmail, password: 'StrongPass123' },
    });
    const studentToken = studentLogin.body && studentLogin.body.token;
    check('student login returns a token', Boolean(studentToken));
    check('student receives the STUDENT role', studentLogin.body.user.role === 'STUDENT');

    const adminEmail = 'admin@university.example';
    await call('POST', '/auth/register', { body: { email: adminEmail, password: 'AdminPass123' } });
    const adminLogin = await call('POST', '/auth/login', {
      body: { email: adminEmail, password: 'AdminPass123' },
    });
    const adminToken = adminLogin.body && adminLogin.body.token;
    check('configured admin email receives the ADMIN role', adminLogin.body.user.role === 'ADMIN');

    const unauthenticated = await call('GET', '/reports');
    check('unauthenticated access is refused', unauthenticated.status === 401);

    // --- Anonymous report ------------------------------------------------
    const anonymous = await call('POST', '/reports', {
      token: studentToken,
      body: {
        person: 'Dr A. Lecturer',
        course: 'BSE 3106',
        location: 'Block C, Room 12',
        description:
          'Repeated inappropriate WhatsApp messages after lectures asking for a private meeting.',
        reportingType: 'ANONYMOUS',
        clientRef: `client-${Date.now()}`,
      },
    });
    check('anonymous report accepted', anonymous.status === 201, anonymous.body.message);
    check('anonymous report receives a case reference',
      typeof anonymous.body.reference === 'string' && anonymous.body.reference.startsWith('HV-'));

    const anonymousId = anonymous.body.reportId;

    // The reporter can still track her own anonymous case.
    const anonymousStatus = await call('GET', `/reports/${anonymousId}/status`, {
      token: studentToken,
    });
    check('reporter can track her own anonymous case',
      anonymousStatus.status === 200 && anonymousStatus.body.status === 'SUBMITTED');

    // --- Idempotent offline synchronisation -------------------------------
    const clientRef = `offline-${Date.now()}`;
    const offlinePayload = {
      clientRef,
      person: 'Mr B. Discussant',
      course: 'BSE 3106',
      location: 'Library basement',
      description: 'Follow-up incident recorded while the device had no connectivity.',
      reportingType: 'CONFIDENTIAL',
    };

    const firstSync = await call('POST', '/reports/sync', {
      token: studentToken,
      body: { reports: [offlinePayload] },
    });
    const secondSync = await call('POST', '/reports/sync', {
      token: studentToken,
      body: { reports: [offlinePayload] },
    });
    check('offline batch synchronisation accepts the first payload',
      firstSync.body.results[0].accepted === true && firstSync.body.results[0].duplicate === false);
    check('replaying the same clientRef does not duplicate the case',
      secondSync.body.results[0].duplicate === true);

    const syncedReportId = firstSync.body.results[0].reportId;
    const detail = await call('GET', `/reports/${syncedReportId}`, { token: studentToken });
    check('synced incident is flagged as captured offline',
      detail.body.report.syncedFromOffline === true);

    const offlineTimeline = detail.body.report.timeline.some(
      (entry) => entry.title === 'Incident recorded on the device while offline',
    );
    check('timeline records the offline capture', offlineTimeline);

    // --- Evidence vault ---------------------------------------------------
    const evidencePayload = Buffer.from('fake screenshot bytes for the smoke test').toString('base64');
    const evidence = await call('POST', `/reports/${syncedReportId}/evidence`, {
      token: studentToken,
      body: {
        fileName: 'whatsapp_screenshot_12_sept.png',
        mimeType: 'image/png',
        dataBase64: evidencePayload,
        note: 'Screenshot taken immediately after the incident.',
      },
    });
    check('evidence upload succeeds', evidence.status === 201, evidence.body.message);
    check('evidence is classified as a screenshot', evidence.body.evidence.kind === 'SCREENSHOT');
    check('evidence is hashed for integrity', /^[a-f0-9]{64}$/.test(evidence.body.evidence.sha256));

    const audioWithoutDeclaration = await call('POST', `/reports/${syncedReportId}/evidence`, {
      token: studentToken,
      body: {
        fileName: 'voice_note.amr',
        mimeType: 'audio/amr',
        dataBase64: evidencePayload,
        lawfulDeclaration: false,
      },
    });
    check('audio evidence requires a lawful-use declaration', audioWithoutDeclaration.status === 400);

    const audioWithDeclaration = await call('POST', `/reports/${syncedReportId}/evidence`, {
      token: studentToken,
      body: {
        fileName: 'voice_note.amr',
        mimeType: 'audio/amr',
        dataBase64: evidencePayload,
        lawfulDeclaration: true,
      },
    });
    check('permitted audio is accepted once declared',
      audioWithDeclaration.status === 201 && audioWithDeclaration.body.evidence.kind === 'AUDIO');

    const evidenceList = await call('GET', `/reports/${syncedReportId}/evidence`, {
      token: studentToken,
    });
    check('evidence vault lists two items', evidenceList.body.evidence.length === 2);

    const downloaded = await fetch(`${BASE}/evidence/${evidence.body.evidence.id}`, {
      headers: { Authorization: `Bearer ${studentToken}` },
    });
    const downloadedBytes = Buffer.from(await downloaded.arrayBuffer()).toString();
    check('evidence download returns the original bytes',
      downloaded.status === 200 && downloadedBytes === 'fake screenshot bytes for the smoke test');

    // --- Follow-up incident on the timeline ------------------------------
    const followUp = await call('POST', `/reports/${syncedReportId}/timeline`, {
      token: studentToken,
      body: { title: 'Subsequent incident', detail: 'Approached again after the test.' },
    });
    check('follow-up incident is appended to the timeline', followUp.status === 201);
    check('timeline stays chronological',
      followUp.body.timeline.every(
        (entry, index, all) => index === 0 || all[index - 1].at <= entry.at,
      ));

    // --- Pattern detection (three independent allegations, same identifier) --
    const sharedDescription =
      'Inappropriate messages requesting a private meeting plus inappropriate comments after class.';
    for (let i = 0; i < 2; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await call('POST', '/reports', {
        token: studentToken,
        body: {
          person: 'Dr A. Lecturer',
          course: 'BSE 3106',
          location: 'Block C',
          description: `${sharedDescription} Report ${i + 1}`,
          reportingType: 'ANONYMOUS',
        },
      });
    }

    const alertsResponse = await call('GET', '/admin/pattern-alerts', { token: adminToken });
    const lecturerAlert = alertsResponse.body.alerts.find(
      (alert) => alert.staffKey === 'dr a. lecturer',
    );
    check('pattern alert raised after three independent allegations', Boolean(lecturerAlert));
    check('pattern alert counts the reports', lecturerAlert && lecturerAlert.reportCount >= 3);
    check('pattern alert reports a behaviour similarity score',
      lecturerAlert && lecturerAlert.behaviourSimilarity > 0);
    check('pattern alert carries a not-guilty notice',
      lecturerAlert && /allegation summary, not a finding of misconduct/.test(lecturerAlert.notice));

    // --- Student case list and confidentiality ----------------------------
    const myCases = await call('GET', '/reports', { token: studentToken });
    check('student sees her own cases including anonymous ones',
      myCases.status === 200 && myCases.body.length >= 4);

    const studentCannotSeeDashboard = await call('GET', '/admin/dashboard', { token: studentToken });
    check('student is refused the institutional dashboard', studentCannotSeeDashboard.status === 403);

    // --- Institutional dashboard ------------------------------------------
    const dashboard = await call('GET', '/admin/dashboard', { token: adminToken });
    check('authorised personnel can open the dashboard', dashboard.status === 200);
    check('dashboard counts received reports',
      dashboard.body.totalReportsReceived >= 4, String(dashboard.body.totalReportsReceived));
    check('dashboard confirms reports are allegations only',
      /allegations only/.test(dashboard.body.notice));

    const adminCaseDetail = await call('GET', `/admin/cases/${syncedReportId}`, { token: adminToken });
    check('officer sees a pseudonym instead of the student identifier',
      adminCaseDetail.body.case.userId === null
      && /Reporter|Anonymous report/.test(adminCaseDetail.body.case.reporterPseudonym));

    // --- Case status update and secure notification ------------------------
    const statusUpdate = await call('PATCH', `/admin/cases/${syncedReportId}/status`, {
      token: adminToken,
      body: { status: 'UNDER_REVIEW', note: 'Assigned to the safeguarding team for triage.' },
    });
    check('authorised personnel can update the case status', statusUpdate.status === 200);

    const invalidStatus = await call('PATCH', `/admin/cases/${syncedReportId}/status`, {
      token: adminToken,
      body: { status: 'NOT_A_STATUS' },
    });
    check('an unknown case status is rejected', invalidStatus.status === 400);

    const notifications = await call('GET', '/notifications', { token: studentToken });
    check('student receives a notification after the status change',
      notifications.body.notifications.length >= 1);
    check('notification title leaks no case details',
      notifications.body.notifications[0].title === 'You have a new confidential notification.');

    const secureMessage = await call('POST', `/admin/cases/${syncedReportId}/message`, {
      token: adminToken,
      body: { message: 'A counsellor can accompany you to the next meeting if you wish.' },
    });
    check('officer can send a secure message', secureMessage.status === 201);

    // --- Audit trail -------------------------------------------------------
    const audit = await call('GET', '/admin/audit-log', { token: adminToken });
    const actions = audit.body.entries.map((entry) => entry.action);
    check('audit log records evidence uploads', actions.includes('EVIDENCE_UPLOADED'));
    check('audit log records status changes', actions.includes('CASE_STATUS_CHANGED'));
    check('audit log records pattern alerts', actions.includes('PATTERN_ALERT_RAISED'));

    const studentCannotReadAudit = await call('GET', '/admin/audit-log', { token: studentToken });
    check('student is refused the audit log', studentCannotReadAudit.status === 403);

    // --- Support directory and emergency support ---------------------------
    const support = await call('GET', '/support/resources', { token: studentToken });
    check('support directory is available',
      support.status === 200 && support.body.resources.length > 0);

    const contacts = await call('GET', '/support/emergency-contacts', { token: studentToken });
    check('emergency contacts include an SMS fallback',
      contacts.body.contacts.some((contact) => contact.type === 'SMS'));
    check('emergency support carries the non-replacement disclaimer',
      /does not replace emergency services/.test(contacts.body.disclaimer));

    const quickSupport = await call('POST', '/support/quick-support', {
      token: studentToken,
      body: { reason: 'Feeling unsafe walking back to the hostel', channel: 'IN_APP' },
    });
    check('quick-support request is logged', quickSupport.status === 201);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    restore();
  }

  const failed = results.filter((result) => !result.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
  if (failed.length) {
    console.log('Failed checks:');
    failed.forEach((result) => console.log(
      `  - ${result.name}${result.detail ? ` (${result.detail})` : ''}`,
    ));
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('Smoke test crashed:', err);
  restore();
  process.exitCode = 1;
});
