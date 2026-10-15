'use strict';

/**
 * Shared report/case helpers used by the report, evidence and admin routes.
 */

const crypto = require('crypto');
const store = require('./store');
const notify = require('./notify');
const {
  CASE_STATUS,
  TIMELINE_KINDS,
  statusIndex,
} = require('./domain');

const REPORTS = 'reports';

function reporterKeyHash(userId) {
  if (!userId) return null;
  return crypto
    .createHash('sha256')
    .update(`${userId}::${process.env.JWT_SECRET || 'dev_secret_change_me'}`)
    .digest('hex');
}

/**
 * Case reference shown to the student. The sequence is derived from how many
 * cases exist in the current year so it stays human-readable in demos.
 */
function nextReference(reports) {
  const year = new Date().getFullYear();
  const prefix = `HV-${year}-`;
  const thisYear = reports.filter((report) => String(report.reference || '').startsWith(prefix)).length;
  return `${prefix}${String(thisYear + 1).padStart(4, '0')}`;
}

function allReports() {
  return store.readCollection(REPORTS, []);
}

function saveReports(reports) {
  store.writeCollection(REPORTS, reports);
}

function findReport(reports, id) {
  return reports.find((report) => report.id === id || report.reference === id) || null;
}

/** The student who created the case may always see it, unless she was anonymous. */
function isOwner(report, user) {
  if (!user || !report) return false;
  if (report.userId && report.userId === user.id) return true;
  // Anonymous cases store only a one-way hash so the student can still track
  // her own case while the institution cannot map it back to her identity.
  return Boolean(report.reporterKeyHash) && report.reporterKeyHash === reporterKeyHash(user.id);
}

function canAccess(report, user) {
  if (!report || !user) return false;
  if (user.role && user.role !== 'STUDENT') return true;
  return isOwner(report, user);
}

/** Institutional read model: identity columns are removed, never masked. */
function institutionalView(report) {
  return {
    ...report,
    userId: null,
    reporterKeyHash: null,
    reporterPseudonym: report.isAnonymous
      ? 'Anonymous report'
      : `Reporter ${String(report.id).slice(-4).toUpperCase()}`,
  };
}

function studentView(report) {
  const view = { ...report };
  delete view.reporterKeyHash;
  return view;
}

function timelineEntry({ kind, title, detail, actorRole = 'STUDENT', actorId = null, at = null }) {
  return {
    id: `tl_${store.nextId()}`,
    kind,
    title,
    detail: detail || null,
    actorRole,
    actorId,
    at: at || new Date().toISOString(),
  };
}

function addTimelineEvent(report, event) {
  if (!Array.isArray(report.timeline)) report.timeline = [];
  const entry = timelineEntry(event);
  report.timeline.push(entry);
  report.timeline.sort((a, b) => (a.at < b.at ? -1 : 1));
  return entry;
}

function addStatusHistory(report, { status, byRole = 'SYSTEM', byId = null, note = null }) {
  if (!Array.isArray(report.statusHistory)) report.statusHistory = [];
  report.statusHistory.push({ status, at: new Date().toISOString(), byRole, byId, note });
}

function reportingPathwayLabel(type) {
  switch (type) {
    case 'IDENTIFIED':
      return 'Identified report: your identity is provided to the authorised personnel handling the complaint.';
    case 'CONFIDENTIAL':
      return 'Confidential report: your identity is protected from unnecessary disclosure and accessible only to authorised personnel.';
    case 'ANONYMOUS':
      return 'Anonymous report: no identity is attached. Anonymous reports may still contribute to pattern detection.';
    default:
      return null;
  }
}

/**
 * Marks a draft as submitted. Drafts live only until the student chooses a
 * reporting pathway, which matches section 3.1 C.
 */
function submitReport(report, { byRole = 'STUDENT', byId = null } = {}) {
  if (report.status !== CASE_STATUS.DRAFT) return report;

  report.status = CASE_STATUS.SUBMITTED;
  report.submittedAt = new Date().toISOString();
  report.timestamp = report.timestamp || Date.parse(report.submittedAt);

  addTimelineEvent(report, {
    kind: TIMELINE_KINDS.REPORT_SUBMITTED,
    title: 'Incident submitted through the selected reporting pathway',
    detail: reportingPathwayLabel(report.reportingType),
    actorRole: byRole,
    actorId: byId,
  });
  addStatusHistory(report, { status: CASE_STATUS.SUBMITTED, byRole, byId });

  return report;
}

function evidenceKindFor(mimeType, fileName) {
  const mime = String(mimeType || '').toLowerCase();
  const name = String(fileName || '').toLowerCase();
  if (mime.startsWith('image/')) {
    return name.includes('screenshot') || name.includes('shot') ? 'SCREENSHOT' : 'PHOTOGRAPH';
  }
  if (mime.startsWith('audio/')) return 'AUDIO';
  if (name.endsWith('.eml') || name.endsWith('.msg')) return 'EMAIL';
  if (name.endsWith('.pdf') || name.endsWith('.doc') || name.endsWith('.docx') || name.endsWith('.txt')) {
    return 'DOCUMENT';
  }
  return 'OTHER';
}

function summarise(report) {
  return {
    id: report.id,
    reference: report.reference,
    person: report.person,
    course: report.course,
    location: report.location,
    reportingType: report.reportingType,
    status: report.status,
    statusIndex: statusIndex(report.status),
    incidentOccurredAt: report.incidentOccurredAt,
    submittedAt: report.submittedAt || null,
    timestamp: report.timestamp,
    evidenceCount: (report.evidence || []).length,
    timelineCount: (report.timeline || []).length,
    patternFlagged: Boolean(report.patternFlagged),
  };
}

/**
 * Sends the deliberately vague "something changed" notification. Anonymous
 * reporters cannot be reached by identity, so nothing is sent for them.
 */
async function statusChangeNotification(report, status) {
  if (!report.userId) return null;
  notify.createNotification({
    userId: report.userId,
    caseId: report.id,
    caseReference: report.reference,
    body:
      'A case on your HERVOICE account has been updated. Open the application and '
      + 'authenticate to see the current status and any message from the authorised officer.',
    critical: true,
  });
  store.appendAudit({
    actorId: null,
    actorRole: 'SYSTEM',
    action: 'CASE_STATUS_NOTIFIED',
    targetType: 'report',
    targetId: report.id,
    detail: status,
  });
  return true;
}

module.exports = {
  REPORTS,
  reporterKeyHash,
  nextReference,
  allReports,
  saveReports,
  findReport,
  isOwner,
  canAccess,
  institutionalView,
  studentView,
  addTimelineEvent,
  addStatusHistory,
  submitReport,
  reportingPathwayLabel,
  evidenceKindFor,
  summarise,
  statusChangeNotification,
};
