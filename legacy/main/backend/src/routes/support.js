'use strict';

/**
 * Support-resource directory and the emergency / quick-support function
 * (sections 3.8 and 3.9 secondary features).
 *
 * The quick-support request is an additional communication channel; it never
 * replaces emergency services or campus security.
 */

const express = require('express');
const store = require('../store');
const { authenticateToken } = require('../security');
const notify = require('../notify');
const { SUPPORT_RESOURCES, EMERGENCY_CONTACTS, EMERGENCY_DISCLAIMER } = require('../supportData');

const router = express.Router();

router.get('/resources', authenticateToken, (req, res) => {
  const category = req.query.category ? String(req.query.category) : null;
  const items = category
    ? SUPPORT_RESOURCES.filter((item) => item.category.toLowerCase() === category.toLowerCase())
    : SUPPORT_RESOURCES;

  const categories = [...new Set(SUPPORT_RESOURCES.map((item) => item.category))];
  return res.json({ categories, resources: items });
});

router.get('/emergency-contacts', authenticateToken, (_req, res) => res.json({
  disclaimer: EMERGENCY_DISCLAIMER,
  contacts: EMERGENCY_CONTACTS,
}));

/**
 * Logs a quick-support request and alerts authorised personnel. The body is
 * deliberately short so the same payload can be sent over the SMS fallback
 * channel when there is no data connectivity.
 */
router.post('/quick-support', authenticateToken, (req, res) => {
  const { reason = 'Immediate danger reported', latitude = null, longitude = null, channel = 'IN_APP' } = req.body;
  const at = new Date().toISOString();

  store.updateCollection('supportRequests', (requests) => {
    requests.push({
      id: `sup_${store.nextId()}`,
      userId: req.user.id,
      reason: String(reason).slice(0, 200),
      latitude: typeof latitude === 'number' ? latitude : null,
      longitude: typeof longitude === 'number' ? longitude : null,
      channel: String(channel),
      at,
    });
    return requests.slice(-1000);
  }, []);

  notify.notifyStaff('SECURE_MESSAGE', {
    caseId: null,
    caseReference: null,
    body: 'A student has requested immediate support through HERVOICE. Open the dashboard to see the details.',
  });

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'QUICK_SUPPORT_REQUESTED',
    targetType: 'support',
    targetId: null,
    detail: String(channel),
  });

  if (channel === 'SMS_FALLBACK') {
    console.warn('[support] SMS fallback used for a quick-support request; no case detail included.');
  }

  return res.status(201).json({
    message: 'Support request logged. Authorised personnel have been alerted.',
    disclaimer: EMERGENCY_DISCLAIMER,
    loggedAt: at,
  });
});

module.exports = router;
