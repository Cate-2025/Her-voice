'use strict';

/**
 * Rule-based pattern detection (section 3.5).
 *
 * The detector NEVER concludes that a member of staff is guilty. It only
 * reports that several independent allegations share a staff identifier and
 * overlapping language, and recommends that authorised personnel review them.
 */

const { CASE_STATUS } = require('./domain');

const DEFAULT_THRESHOLD = Number(process.env.PATTERN_THRESHOLD || 3);

const STOP_WORDS = new Set([
  'the', 'and', 'for', 'with', 'that', 'this', 'was', 'were', 'are', 'has', 'had', 'have',
  'she', 'her', 'hers', 'him', 'his', 'they', 'them', 'would', 'could', 'should', 'about',
  'from', 'into', 'then', 'than', 'when', 'what', 'which', 'while', 'after', 'before',
  'asked', 'told', 'said', 'also', 'again', 'because', 'been', 'being', 'very', 'just',
]);

function normaliseIdentifier(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function tokenize(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((token) => token.length > 3 && !STOP_WORDS.has(token));
}

/** Jaccard similarity over the meaningful words of two descriptions. */
function similarity(a, b) {
  const left = new Set(tokenize(a));
  const right = new Set(tokenize(b));
  if (left.size === 0 || right.size === 0) return 0;
  let shared = 0;
  left.forEach((token) => {
    if (right.has(token)) shared += 1;
  });
  return shared / (left.size + right.size - shared);
}

function sharedKeywords(reports) {
  if (reports.length < 2) return [];
  const counts = new Map();
  reports.forEach((report) => {
    new Set(tokenize(report.description)).forEach((token) => {
      counts.set(token, (counts.get(token) || 0) + 1);
    });
  });
  return [...counts.entries()]
    .filter(([, count]) => count >= Math.max(2, Math.ceil(reports.length / 2)))
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([token]) => token);
}

/**
 * Builds the list of pattern alerts for a set of reports.
 * Drafts and withdrawn reports are excluded so the counter reflects reports the
 * institution has actually received.
 */
function buildPatternAlerts(reports, threshold = DEFAULT_THRESHOLD) {
  const considered = reports.filter((report) => report.status && report.status !== CASE_STATUS.DRAFT);

  const grouped = new Map();
  considered.forEach((report) => {
    const key = normaliseIdentifier(report.person);
    if (!key) return;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(report);
  });

  const alerts = [];
  grouped.forEach((group, key) => {
    if (group.length < threshold) return;

    // "Independent" = not attributable to a single known reporter. Anonymous
    // reports are counted individually because each submission is a separate
    // disclosure, but they can never be traced back to a person.
    const distinctReporters = new Set(
      group.map((report) => (report.userId == null ? `anon:${report.id}` : `user:${report.userId}`)),
    );

    const pairSimilarities = [];
    for (let i = 0; i < group.length; i += 1) {
      for (let j = i + 1; j < group.length; j += 1) {
        pairSimilarities.push(similarity(group[i].description, group[j].description));
      }
    }
    const averageSimilarity = pairSimilarities.length
      ? pairSimilarities.reduce((sum, value) => sum + value, 0) / pairSimilarities.length
      : 0;

    const courses = [...new Set(group.map((report) => report.course).filter(Boolean))];
    const locations = [...new Set(group.map((report) => report.location).filter(Boolean))];

    alerts.push({
      staffIdentifier: group[0].person,
      staffKey: key,
      reportCount: group.length,
      independentReporterCount: distinctReporters.size,
      behaviourSimilarity: Number(averageSimilarity.toFixed(2)),
      sharedKeywords: sharedKeywords(group),
      relatedCourses: courses,
      relatedLocations: locations,
      firstReportedAt: Math.min(...group.map((report) => report.timestamp || 0)),
      lastReportedAt: Math.max(...group.map((report) => report.timestamp || 0)),
      severity: distinctReporters.size >= 3 && averageSimilarity >= 0.25 ? 'HIGH' : 'MODERATE',
      reportIds: group.map((report) => report.id),
      notice: 'Potential recurring pattern detected. This is an allegation summary, not a finding of misconduct.',
      recommendation: 'Authorised institutional review recommended.',
    });
  });

  return alerts.sort((a, b) => b.reportCount - a.reportCount);
}

function alertForStaffMember(reports, person, threshold = DEFAULT_THRESHOLD) {
  const key = normaliseIdentifier(person);
  return buildPatternAlerts(reports, threshold).find((alert) => alert.staffKey === key) || null;
}

module.exports = {
  DEFAULT_THRESHOLD,
  normaliseIdentifier,
  similarity,
  buildPatternAlerts,
  alertForStaffMember,
};
