'use strict';

/**
 * HERVOICE backend API.
 *
 * Layers implemented here (section 7.1 of the concept paper):
 *   - HTTP/REST API layer for the Flutter client
 *   - Authentication, role-based access control and audit logging
 *   - Report/case management, evidence metadata, notifications
 *   - Rule-based pattern detection for authorised personnel
 *
 * Data is persisted as JSON collections under backend/data and evidence bytes
 * under backend/uploads, which stand in for the database and the secure
 * evidence storage shown in the architecture diagram.
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

const store = require('./src/store');
const domain = require('./src/domain');
const authRoutes = require('./src/routes/auth');
const reportRoutes = require('./src/routes/reports');
const evidenceRoutes = require('./src/routes/evidence');
const notificationRoutes = require('./src/routes/notifications');
const supportRoutes = require('./src/routes/support');
const adminRoutes = require('./src/routes/admin');

const app = express();

store.ensureStorage();

app.use(cors());

// Evidence is transferred as base64 inside JSON so the prototype needs no
// multipart dependency; the limit is deliberately above MAX_EVIDENCE_BYTES to
// allow for base64 overhead.
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '15mb' }));

app.use((req, _res, next) => {
  // Request logging that never echoes payload contents into the console.
  console.log(`${new Date().toISOString()} ${req.method} ${req.originalUrl}`);
  next();
});

// --- Static evidence serving is intentionally NOT enabled -----------------
// Evidence is only ever served through the access-checked route in
// src/routes/evidence.js so that every read is authorised and audited.

// --- Routes ---------------------------------------------------------------
app.use('/api/auth', authRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/admin', adminRoutes);
// Report and evidence routes share the /api prefix so the paths read naturally:
// /api/reports/:id/evidence and /api/evidence/:id
app.use('/api', evidenceRoutes);
app.use('/api/reports', reportRoutes);

app.get('/api/health', (_req, res) => res.json({
  status: 'ok',
  service: 'hervoice-backend',
  version: require('./package.json').version,
  serverTime: new Date().toISOString(),
}));

/**
 * Vocabulary endpoint. The Flutter client fetches this at start-up so the two
 * codebases cannot drift apart on status or reporting-type names.
 */
app.get('/api/meta', (_req, res) => res.json({
  reportingTypes: domain.REPORTING_TYPES,
  caseStatusFlow: domain.CASE_STATUS_FLOW,
  evidenceKinds: Object.values(domain.EVIDENCE_KINDS),
  notificationCategories: Object.values(domain.NOTIFICATION_CATEGORIES),
}));

app.use((req, res) => res.status(404).json({
  message: `No route for ${req.method} ${req.originalUrl}`,
}));

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('[hervoice] Unhandled error:', err.message);
  res.status(err.status || 500).json({ message: err.message || 'Unexpected server error' });
});

const port = Number(process.env.PORT || 4000);

if (require.main === module) {
  app.listen(port, '0.0.0.0', () => {
    console.log('HERVOICE backend running on port', port);
    console.log('Evidence storage:', path.join(__dirname, 'uploads'));
    console.log('Data collections:', store.DATA_DIR);
  });
}

module.exports = app;
