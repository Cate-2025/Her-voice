'use strict';

/**
 * Shared domain vocabulary for HERVOICE.
 *
 * These enums are the single source of truth for the reporting pathways
 * (section 3.4) and the case lifecycle (section 3.1 C) and are mirrored by the
 * Flutter client, so keep both in step.
 */

const REPORTING_TYPES = Object.freeze(['IDENTIFIED', 'CONFIDENTIAL', 'ANONYMOUS']);

const CASE_STATUS = Object.freeze({
  DRAFT: 'DRAFT', // Stored locally / on server but not yet submitted
  SUBMITTED: 'SUBMITTED', // Received by the institution
  UNDER_REVIEW: 'UNDER_REVIEW', // Being triaged by an authorised officer
  INVESTIGATING: 'INVESTIGATING',
  ACTION_TAKEN: 'ACTION_TAKEN',
  REFERRED: 'REFERRED', // Sent to another institutional body
  CLOSED: 'CLOSED',
});

const CASE_STATUS_FLOW = Object.freeze([
  CASE_STATUS.DRAFT,
  CASE_STATUS.SUBMITTED,
  CASE_STATUS.UNDER_REVIEW,
  CASE_STATUS.INVESTIGATING,
  CASE_STATUS.ACTION_TAKEN,
  CASE_STATUS.REFERRED,
  CASE_STATUS.CLOSED,
]);

const TIMELINE_KINDS = Object.freeze({
  INCIDENT_RECORDED: 'INCIDENT_RECORDED',
  EVIDENCE_ADDED: 'EVIDENCE_ADDED',
  FOLLOW_UP: 'FOLLOW_UP',
  REPORT_SUBMITTED: 'REPORT_SUBMITTED',
  STATUS_CHANGED: 'STATUS_CHANGED',
  OFFICER_MESSAGE: 'OFFICER_MESSAGE',
});

const EVIDENCE_KINDS = Object.freeze({
  SCREENSHOT: 'SCREENSHOT',
  EMAIL: 'EMAIL',
  PHOTOGRAPH: 'PHOTOGRAPH',
  DOCUMENT: 'DOCUMENT',
  AUDIO: 'AUDIO',
  OTHER: 'OTHER',
});

/** Notification categories are intentionally vague for lock-screen safety. */
const NOTIFICATION_CATEGORIES = Object.freeze({
  CASE_UPDATE: 'CASE_UPDATE',
  SECURE_MESSAGE: 'SECURE_MESSAGE',
  SYSTEM: 'SYSTEM',
});

const PRIVACY_SAFE_NOTIFICATION_TITLES = Object.freeze({
  CASE_UPDATE: 'You have a new confidential notification.',
  SECURE_MESSAGE: 'You have a new secure message.',
  SYSTEM: 'HERVOICE notification.',
});

/** Indian/International style status ordering used by the timeline renderer. */
function statusIndex(status) {
  const index = CASE_STATUS_FLOW.indexOf(status);
  return index === -1 ? 0 : index;
}

function isValidStatus(status) {
  return CASE_STATUS_FLOW.includes(status);
}

function isValidReportingType(type) {
  return REPORTING_TYPES.includes(type);
}

/**
 * Evidence captures the student's own declaration that the recording was
 * lawful, as required by the risk table in section 9.
 */
function requiresLawfulDeclaration(kind) {
  return kind === EVIDENCE_KINDS.AUDIO;
}

module.exports = {
  REPORTING_TYPES,
  CASE_STATUS,
  CASE_STATUS_FLOW,
  TIMELINE_KINDS,
  EVIDENCE_KINDS,
  NOTIFICATION_CATEGORIES,
  PRIVACY_SAFE_NOTIFICATION_TITLES,
  statusIndex,
  isValidStatus,
  isValidReportingType,
  requiresLawfulDeclaration,
};
