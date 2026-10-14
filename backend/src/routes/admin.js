'use strict';

/**
 * Institutional dashboard API (core feature: section 3.9, architecture 7.2).
 *
 * Every endpoint here requires an authenticated safeguarding officer or
 * administrator, and every state-changing or evidence-reading action is
 * written to the audit trail (section 3.12 VI).
 */

const express = require('express');
const store = require('../store');
const { authenticateToken, requireStaff, requireAdmin } = require('../security');
const svc = require('../reportsService');
const notify = require('../notify');
const { buildPatternAlerts } = require('../patternDetection');
const {
  CASE_STATUS,
  CASE_STATUS_FLOW,
  TIMELINE_KINDS,
  isValidStatus,
} = require('../domain');

const router = express.Router();

router.use(authenticateToken);

// --- Dashboard summary ----------------------------------------------------
router.get('/dashboard', requireStaff, (req, res) => {
  const reports = svc.allReports();
  const received = reports.filter((report) => report.status !== CASE_STATUS.DRAFT);

  const byStatus = CASE_STATUS_FLOW.reduce((accumulator, status) => {
    accumulator[status] = received.filter((report) => report.status === status).length;
    return accumulator;
  }, {});

  const byReportingType = ['IDENTIFIED', 'CONFIDENTIAL', 'ANONYMOUS'].reduce((accumulator, type) => {
    accumulator[type] = received.filter((report) => report.reportingType === type).length;
    return accumulator;
  }, {});

  const alerts = buildPatternAlerts(reports);

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'DASHBOARD_VIEWED',
    targetType: 'dashboard',
    targetId: null,
    detail: `${received.length} received case(s)`,
  });

  return res.json({
    totalReportsReceived: received.length,
    drafts: reports.length - received.length,
    evidenceItems: reports.reduce((sum, report) => sum + (report.evidence || []).length, 0),
    activePatternAlerts: alerts,
    byStatus,
    byReportingType,
    quickSupportRequests: store.readCollection('supportRequests', []).length,
    cases: received
      .sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
      .map((report) => svc.summarise(svc.institutionalView(report))),
    notice:
      'Reports are allegations only. HERVOICE does not determine guilt; '
      + 'the authorised institutional investigation process does.',
  });
});

// --- Case list ------------------------------------------------------------
router.get('/cases', requireStaff, (req, res) => {
  const { status, reportingType, flaggedOnly } = req.query;
  let reports = svc.allReports().filter((report) => report.status !== CASE_STATUS.DRAFT);

  if (status) reports = reports.filter((report) => report.status === String(status).toUpperCase());
  if (reportingType) {
    reports = reports.filter((report) => report.reportingType === String(reportingType).toUpperCase());
  }
  if (String(flaggedOnly).toLowerCase() === 'true') {
    reports = reports.filter((report) => report.patternFlagged);
  }

  reports.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
  return res.json({ cases: reports.map((report) => svc.summarise(svc.institutionalView(report))) });
});

// --- Case detail (identity columns removed for anonymous reports) ---------
router.get('/cases/:id', requireStaff, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'CASE_VIEWED',
    targetType: 'report',
    targetId: report.id,
    detail: `Case ${report.reference}`,
  });

  return res.json({ case: svc.institutionalView(report) });
});

// --- Case status update ---------------------------------------------------
router.patch('/cases/:id/status', requireStaff, (req, res) => {
  const { status, note } = req.body;
  if (!isValidStatus(status)) {
    return res.status(400).json({ message: `status must be one of ${CASE_STATUS_FLOW.join(', ')}` });
  }

  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });

  const previous = report.status;
  report.status = status;
  report.updatedAt = new Date().toISOString();

  svc.addStatusHistory(report, {
    status,
    byRole: req.user.role,
    byId: req.user.id,
    note: note ? String(note).slice(0, 500) : null,
  });

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.STATUS_CHANGED,
    title: `Case status changed to ${status.replace(/_/g, ' ').toLowerCase()}`,
    detail: note ? String(note).slice(0, 500) : `Previous status: ${previous}`,
    actorRole: req.user.role,
    actorId: req.user.id,
  });

  svc.saveReports(reports);
  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'CASE_STATUS_CHANGED',
    targetType: 'report',
    targetId: report.id,
    detail: `${previous} -> ${status}`,
  });

  svc.statusChangeNotification(report, status);

  return res.json({ message: 'Case status updated', case: svc.institutionalView(report) });
});

// --- Assign an officer ----------------------------------------------------
router.post('/cases/:id/assign', requireAdmin, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });

  report.assignedOfficerId = req.user.id;
  report.assignedAt = new Date().toISOString();

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.STATUS_CHANGED,
    title: 'Case assigned to an authorised officer',
    detail: 'An officer will review the report and any preserved evidence.',
    actorRole: req.user.role,
    actorId: req.user.id,
  });

  svc.saveReports(reports);
  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'CASE_ASSIGNED',
    targetType: 'report',
    targetId: report.id,
    detail: null,
  });

  return res.json({ message: 'Case assigned', case: svc.institutionalView(report) });
});

// --- Secure message to the reporter ---------------------------------------
/**
 * Communication with authorised personnel without unnecessarily exposing
 * sensitive information (section 2.2 VI). The notification is generic; the
 * message content stays inside the application.
 */
router.post('/cases/:id/message', requireStaff, (req, res) => {
  const { message } = req.body;
  if (!String(message || '').trim()) return res.status(400).json({ message: 'message is required' });

  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.OFFICER_MESSAGE,
    title: 'Message from authorised personnel',
    detail: String(message).slice(0, 2000),
    actorRole: req.user.role,
    actorId: req.user.id,
  });

  svc.saveReports(reports);

  if (report.userId) {
    notify.createNotification({
      userId: report.userId,
      category: 'SECURE_MESSAGE',
      caseId: report.id,
      caseReference: report.reference,
      body:
        'You have a new secure message from authorised personnel. '
        + 'Open the application and authenticate to read it.',
      critical: true,
    });
  }

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'OFFICER_MESSAGE_SENT',
    targetType: 'report',
    targetId: report.id,
    detail: null,
  });

  return res.status(201).json({ message: 'Secure message delivered', case: svc.institutionalView(report) });
});

// --- Pattern alerts -------------------------------------------------------
router.get('/pattern-alerts', requireStaff, (_req, res) => {
  const reports = svc.allReports();
  return res.json({
    threshold: Number(process.env.PATTERN_THRESHOLD || 3),
    notice:
      'A pattern alert indicates that several independent allegations share a staff identifier. '
      + 'It is not a finding of misconduct and must be reviewed by authorised personnel.',
    alerts: buildPatternAlerts(reports),
  });
});

// --- Audit log ------------------------------------------------------------
router.get('/audit-log', requireAdmin, (req, res) => {
  const limit = Math.min(Number(req.query.limit || 100), 500);
  const entries = store.readCollection('audit', []);
  return res.json({ total: entries.length, entries: entries.slice(-limit).reverse() });
});

module.exports = router;
