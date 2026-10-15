'use strict';

/**
 * Evidence Vault API (section 3.1 B and 3.2).
 *
 * Evidence metadata is stored with the incident record, while the bytes are
 * written to a separate secure-storage directory, which mirrors section 7.1 of
 * the architecture. A hash of every file is retained so tampering can be
 * detected later.
 *
 * Transport is base64 inside a JSON body rather than multipart/form-data so the
 * prototype needs no additional server dependency and so the device can queue
 * the exact same payload while offline.
 */

const crypto = require('crypto');
const express = require('express');
const store = require('../store');
const { authenticateToken } = require('../security');
const svc = require('../reportsService');
const { TIMELINE_KINDS, requiresLawfulDeclaration, EVIDENCE_KINDS } = require('../domain');

const router = express.Router();

const MAX_EVIDENCE_BYTES = Number(process.env.MAX_EVIDENCE_BYTES || 10 * 1024 * 1024);

function findReportAndEvidence(evidenceId) {
  const reports = svc.allReports();
  for (const report of reports) {
    const evidence = (report.evidence || []).find((item) => item.id === evidenceId);
    if (evidence) return { reports, report, evidence };
  }
  return { reports, report: null, evidence: null };
}

// --- Upload ---------------------------------------------------------------
router.post('/reports/:id/evidence', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });

  const {
    fileName,
    mimeType = 'application/octet-stream',
    kind,
    note,
    dataBase64,
    capturedAt,
    lawfulDeclaration = false,
  } = req.body;

  if (!fileName) return res.status(400).json({ message: 'fileName is required' });
  if (!dataBase64) return res.status(400).json({ message: 'dataBase64 is required' });

  let buffer;
  try {
    buffer = Buffer.from(String(dataBase64).replace(/^data:[^;]+;base64,/, ''), 'base64');
  } catch (err) {
    return res.status(400).json({ message: 'Evidence payload is not valid base64' });
  }

  if (!buffer.length) return res.status(400).json({ message: 'Evidence payload is empty' });
  if (buffer.length > MAX_EVIDENCE_BYTES) {
    const limitMb = Math.round(MAX_EVIDENCE_BYTES / (1024 * 1024));
    return res.status(413).json({ message: `Evidence file exceeds the ${limitMb} MB prototype limit` });
  }

  const resolvedKind = EVIDENCE_KINDS[kind] ? kind : svc.evidenceKindFor(mimeType, fileName);
  if (requiresLawfulDeclaration(resolvedKind) && !lawfulDeclaration) {
    return res.status(400).json({
      message:
        'For audio evidence you must confirm that the recording was collected and will be used '
        + 'only where lawful and permitted by institutional policy.',
    });
  }

  const evidenceId = `evd_${store.nextId()}`;
  let storedName = null;
  try {
    storedName = store.saveEvidenceFile(evidenceId, fileName, buffer).storedName;
  } catch (err) {
    return res.status(500).json({ message: `Could not store the evidence file: ${err.message}` });
  }

  const metadata = {
    id: evidenceId,
    kind: resolvedKind,
    originalName: String(fileName),
    storedName,
    mimeType: String(mimeType),
    sizeBytes: buffer.length,
    sha256: crypto.createHash('sha256').update(buffer).digest('hex'),
    note: note ? String(note).slice(0, 500) : null,
    lawfulDeclaration: Boolean(lawfulDeclaration),
    capturedAt: capturedAt || new Date().toISOString(),
    uploadedAt: new Date().toISOString(),
    uploadedBy: req.user.id,
  };

  if (!Array.isArray(report.evidence)) report.evidence = [];
  report.evidence.push(metadata);

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.EVIDENCE_ADDED,
    title: `Evidence preserved: ${metadata.originalName}`,
    detail: `${resolvedKind} - ${(metadata.sizeBytes / 1024).toFixed(0)} KB, sha256 ${metadata.sha256.slice(0, 12)}...`,
    actorRole: req.user.role,
    actorId: req.user.id,
  });

  svc.saveReports(reports);
  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'EVIDENCE_UPLOADED',
    targetType: 'evidence',
    targetId: evidenceId,
    detail: `${resolvedKind} attached to ${report.reference}`,
  });

  return res.status(201).json({
    message: 'Evidence preserved',
    evidence: metadata,
    reference: report.reference,
  });
});

// --- List metadata --------------------------------------------------------
router.get('/reports/:id/evidence', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });

  if (req.user.role && req.user.role !== 'STUDENT') {
    store.appendAudit({
      actorId: req.user.id,
      actorRole: req.user.role,
      action: 'EVIDENCE_METADATA_VIEWED',
      targetType: 'report',
      targetId: report.id,
      detail: `${(report.evidence || []).length} evidence item(s) listed`,
    });
  }

  const metadata = (report.evidence || []).map((item) => ({
    ...item,
    downloadUrl: `/api/evidence/${item.id}`,
  }));
  return res.json({ evidence: metadata });
});

// --- Download -------------------------------------------------------------
/**
 * Restricted access to evidence content (section 3.12 V). Students can only
 * retrieve their own files; every institutional access is written to the audit
 * trail.
 */
router.get('/evidence/:evidenceId', authenticateToken, (req, res) => {
  const { report, evidence } = findReportAndEvidence(req.params.evidenceId);
  if (!evidence) return res.status(404).json({ message: 'Evidence not found' });
  if (!svc.canAccess(report, req.user)) return res.status(403).json({ message: 'Not authorised' });

  let absolutePath;
  try {
    absolutePath = store.evidenceAbsolutePath(evidence.storedName);
  } catch (err) {
    return res.status(400).json({ message: 'Evidence reference is invalid' });
  }

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'EVIDENCE_DOWNLOADED',
    targetType: 'evidence',
    targetId: evidence.id,
    detail: `Case ${report.reference}`,
  });

  res.setHeader('Content-Type', evidence.mimeType || 'application/octet-stream');
  return res.download(absolutePath, evidence.originalName, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ message: 'Evidence file is missing from storage' });
    }
  });
});

// --- Remove ---------------------------------------------------------------
router.delete('/reports/:id/evidence/:evidenceId', authenticateToken, (req, res) => {
  const reports = svc.allReports();
  const report = svc.findReport(reports, req.params.id);
  if (!report) return res.status(404).json({ message: 'Case not found' });
  if (!svc.isOwner(report, req.user)) return res.status(403).json({ message: 'Not authorised' });

  const index = (report.evidence || []).findIndex((item) => item.id === req.params.evidenceId);
  if (index === -1) return res.status(404).json({ message: 'Evidence not found' });

  const [removed] = report.evidence.splice(index, 1);
  try {
    store.deleteEvidenceFile(removed.storedName);
  } catch (err) {
    console.warn(`[evidence] Could not delete ${removed.storedName}: ${err.message}`);
  }

  svc.addTimelineEvent(report, {
    kind: TIMELINE_KINDS.EVIDENCE_ADDED,
    title: `Evidence removed: ${removed.originalName}`,
    detail: 'The student withdrew this item before the institution reviewed it.',
    actorRole: req.user.role,
    actorId: req.user.id,
  });

  svc.saveReports(reports);
  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'EVIDENCE_DELETED',
    targetType: 'evidence',
    targetId: removed.id,
    detail: `Removed from ${report.reference}`,
  });

  return res.json({ message: 'Evidence removed', evidence: report.evidence });
});

module.exports = router;
