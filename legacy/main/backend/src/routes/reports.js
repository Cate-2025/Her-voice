'use strict';

/**
 * Incident reporting, the incident timeline and case submission
 * (sections 3.1, 3.3, 3.4 and 3.9).
 */

const express = require('express');
const store = require('../store');
const { authenticateToken } = require('../security');
const notify = require('../notify');
const svc = require('../reportsService');
const { buildPatternAlerts } = require('../patternDetection');
const {
  CASE_STATUS,
  TIMELINE_KINDS,
  isValidReportingType,
  isValidStatus,
} = require('../domain');

const router = express.Router();

function validateIncidentBody(body, { requireAll = true } = {}) {
  const problems = [];
  ['person', 'course', 'location', 'description'].forEach((field) => {
    if (requireAll && !String(body[field] || '').trim()) problems.push(`${field} is required`);
  });
  if (body.reportingType && !isValidReportingType(body.reportingType)) {
    problems.push('reportingType must be IDENTIFIED, CONFIDENTIAL or ANONYMOUS');
  }
  if (requireAll && !isValidReportingType(body.reportingType)) {
    problems.push('reportingType is required');
  }
  return problems;
}

function buildReport(user, body) {
  const reportingType = body.reportingType;
  const isAnonymous = reportingType === 'ANONYMOUS';
  const now = new Date().toISOString();

  return {
    id: `rpt_${store.nextId()}`,
    reference: null, // assigned by the caller, which holds the full collection
    userId: isAnonymous ? null : user.id,
    reporterKeyHash: isAnonymous ? svc.reporterKeyHash(user.id) : null,
    isAnonymous,
    person: String(body.person).trim(),
    course: String(body.course).trim(),
    location: String(body.location).trim(),
    locationLabel: body.locationLabel ? String(body.locationLabel) : null,
    latitude: typeof body.latitude === 'number' ? body.latitude : null,
    longitude: typeof body.longitude === 'number' ? body.longitude : null,
    description: String(body.description).trim(),
    witnesses: body.witnesses ? String(body.witnesses).trim() : null,
    reportingType,
    status: CASE_STATUS.DRAFT,
    incidentOccurredAt: body.incidentOccurredAt || now,
    timestamp: Date.now(),
    createdAt: now,
    submittedAt: null,
    clientRef: body.clientRef || null,
    syncedFromOffline: Boolean(body.syncedFromOffline),
    assignedOfficerId: null,
    patternFlagged: false,
    evidence: [],
    timeline: [],
    statusHistory: [],
  };
}

/** Re-runs the rule-based detector and raises privacy-safe staff alerts. */
function runPatternDetection(reports) {
  const alerts = buildPatternAlerts(reports);
  const flaggedIds = new Set(alerts.flatMap((alert) => alert.reportIds));
  reports.forEach((report) => {
    report.patternFlagged = flaggedIds.has(report.id);
  });

  const knownAlerts = store.readCollection('patternAlerts', []);
  const newAlerts = alerts.filter(
    (alert) => !knownAlerts.some(
      (known) => known.staffKey === alert.staffKey && known.reportCount >= alert.reportCount,
    ),
  );

  if (newAlerts.length) {
    const detectedAt = new Date().toISOString();
    store.writeCollection('patternAlerts', alerts.map((alert) => ({ ...alert, detectedAt })));
    newAlerts.forEach((alert) => {
      store.appendAudit({
        actorId: null,
        actorRole: 'SYSTEM',
        action: 'PATTERN_ALERT_RAISED',
        targetType: 'staff_identifier',
        targetId: alert.staffKey,
        detail: `${alert.reportCount} independent allegations, similarity ${alert.behaviourSimilarity}`,
      });
      notify.notifyStaff('SYSTEM', {
        caseId: null,
        caseReference: null,
        body:
          'An internal pattern alert is available for authorised review. Multiple independent '
          + 'allegations share a staff identifier. This is not a finding of misconduct.',
      });
    });
  }

  return alerts;
}

// --- Create ---------------------------------------------------------------
router.post('/', authenticateToken, (req, res) => {
  const problems = validateIncidentBody(req.body);
  if (problems.length) return res.status(400).json({ message: problems.join('. ') });

  const reports = svc.allReports();

  // Offline synchronisation is idempotent: replaying the same clientRef must
  // not create a duplicate incident (section 7.3).
  if (req.body.clientRef) {
    const existing = reports.find((report) => report.clientRef === req.body.clientRef);
    if (existing) {
      return res.json({
        message: 'Incident already synchronised',
        duplicate: true,
        report: svc.studentView(existing),
        patternDetected: existing.patternFlagged,
      });
    }
  }

  const report = buildReport(req.user, req.body);
  report.reference = svc.nextReference(reports);

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.INCIDENT_RECORDED,
    title: 'Incident recorded',
    detail: req.body.description ? String(req.body.description).slice(0, 240) : null,
    actorId: req.user.id,
    at: report.incidentOccurredAt,
  });

  const shouldSubmit = String(req.body.status || '').toUpperCase() !== CASE_STATUS.DRAFT;
  if (shouldSubmit) svc.submitReport(report, { byId: req.user.id });

  reports.push(report);
  const alerts = runPatternDetection(reports);
  svc.saveReports(reports);

  const alert = alerts.find(
    (entry) => entry.staffKey === String(report.person).trim().toLowerCase(),
  ) || null;

  return res.status(201).json({
    message: shouldSubmit ? 'Incident reported successfully' : 'Incident draft saved',
    reportId: report.id,
    reference: report.reference,
    status: report.status,
    duplicate: false,
    patternDetected: alert !== null,
    alert,
  });
});

// --- Batch synchronisation of incidents recorded while offline -------------
router.post('/sync', authenticateToken, (req, res) => {
  const incoming = Array.isArray(req.body.reports) ? req.body.reports : [];
  if (!incoming.length) return res.json({ results: [], alerts: [] });

  const reports = svc.allReports();
  const results = [];

  incoming.forEach((payload) => {
    if (payload.clientRef && reports.some((report) => report.clientRef === payload.clientRef)) {
      results.push({ clientRef: payload.clientRef, accepted: true, duplicate: true });
      return;
    }

    const problems = validateIncidentBody(payload);
    if (problems.length) {
      results.push({
        clientRef: payload.clientRef || null,
        accepted: false,
        message: problems.join('. '),
      });
      return;
    }

    const report = buildReport(req.user, { ...payload, syncedFromOffline: true });
    report.reference = svc.nextReference(reports);
    svc.addTimelineEvent(report, {
      kind: TIMELINE_KINDS.INCIDENT_RECORDED,
      title: 'Incident recorded on the device while offline',
      detail: 'Synchronised with the server once connectivity was restored.',
      actorId: req.user.id,
      at: report.incidentOccurredAt,
    });
    if (String(payload.status || '').toUpperCase() !== CASE_STATUS.DRAFT) {
      svc.submitReport(report, { byId: req.user.id });
    }
    reports.push(report);
    results.push({
      clientRef: report.clientRef,
      accepted: true,
      duplicate: false,
      reportId: report.id,
      reference: report.reference,
    });
  });

  const alerts = runPatternDetection(reports);
  svc.saveReports(reports);

  return res.json({ results, alerts });
});

// --- List my cases --------------------------------------------------------
router.get('/', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const mine = reports.filter((report) => svc.isOwner(report, req.user));
  mine.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
  return res.json(mine.map((report) => svc.summarise(report)));
});

// --- Case detail ----------------------------------------------------------
router.get('/:id', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });
  return res.json({ report: svc.studentView(report) });
});

// --- Update a draft -------------------------------------------------------
router.patch('/:id', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.isOwner(report, req.user)) return res.status(403).json({ message: 'Not authorised' });
  if (report.status !== CASE_STATUS.DRAFT) {
    return res.status(409).json({
      message: 'Only drafts can be edited. Submit a follow-up event instead.',
    });
  }

  const editable = [
    'person', 'course', 'location', 'locationLabel',
    'description', 'witnesses', 'incidentOccurredAt',
  ];
  editable.forEach((field) => {
    if (req.body[field] !== undefined) report[field] = req.body[field];
  });

  if (req.body.reportingType && isValidReportingType(req.body.reportingType)) {
    report.reportingType = req.body.reportingType;
    report.isAnonymous = req.body.reportingType === 'ANONYMOUS';
    report.userId = report.isAnonymous ? null : req.user.id;
    report.reporterKeyHash = report.isAnonymous ? svc.reporterKeyHash(req.user.id) : null;
  }

  if (Array.isArray(report.timeline) && report.timeline.length) {
    report.timeline[0].title = 'Incident recorded';
    report.timeline[0].detail = String(report.description).slice(0, 240);
  }

  svc.saveReports(reports);
  return res.json({ message: 'Draft updated', report: svc.studentView(report) });
});

// --- Timeline -------------------------------------------------------------
router.get('/:id/timeline', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });
  return res.json({ timeline: report.timeline || [] });
});

/** Follow-up incidents (section 3.1 A, item VII). */
router.post('/:id/timeline', authenticateToken, (req, res) => {
  const { title, detail, at } = req.body;
  if (!title && !detail) return res.status(400).json({ message: 'A title or detail is required' });

  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });

  const entry = svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.FOLLOW_UP,
    title: title || 'Follow-up incident recorded',
    detail: detail || null,
    actorRole: req.user.role,
    actorId: req.user.id,
    at: at || null,
  });

  svc.saveReports(reports);
  return res.status(201).json({ message: 'Timeline updated', entry, timeline: report.timeline });
});

// --- Submit a draft -------------------------------------------------------
router.post('/:id/submit', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.isOwner(report, req.user)) return res.status(403).json({ message: 'Not authorised' });
  if (report.status !== CASE_STATUS.DRAFT) {
    return res.status(409).json({ message: 'This case has already been submitted' });
  }

  svc.submitReport(report, { byId: req.user.id });
  const alerts = runPatternDetection(reports);
  svc.saveReports(reports);

  if (report.userId) {
    notify.createNotification({
      userId: report.userId,
      caseId: report.id,
      caseReference: report.reference,
      body: 'Your report has been received. Open the application and authenticate to track its progress.',
    });
  }

  return res.json({
    message: 'Incident reported successfully',
    reference: report.reference,
    status: report.status,
    patternDetected: report.patternFlagged,
    alert: alerts.find(
      (entry) => entry.staffKey === String(report.person).trim().toLowerCase(),
    ) || null,
  });
});

// --- Case status tracking -------------------------------------------------
router.get('/:id/status', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });
  return res.json({
    reference: report.reference,
    status: isValidStatus(report.status) ? report.status : CASE_STATUS.SUBMITTED,
    statusHistory: report.statusHistory || [],
    assignedOfficer: report.assignedOfficerId ? 'Assigned' : 'Not yet assigned',
  });
});

module.exports = router;
