'use strict';

/**
 * Secure notification endpoints (section 3.6) plus push-token registration,
 * which is what enables the SMS fallback decision in notify.js.
 */

const express = require('express');
const store = require('../store');
const { authenticateToken } = require('../security');
const notify = require('../notify');

const router = express.Router();

// --- My notifications -----------------------------------------------------
router.get('/', authenticateToken, (req, res) => {
  const items = notify.listForUser(req.user.id);
  return res.json({
    unreadCount: items.filter((item) => !item.read).length,
    notifications: items,
    privacyNotice:
      'Lock-screen text never contains case details. Authenticate and open a notification to read it.',
  });
});

router.post('/:id/read', authenticateToken, (req, res) => {
  let updated = null;
  store.updateCollection('notifications', (items) => items.map((item) => {
    if (item.id === req.params.id && item.userId === req.user.id) {
      updated = { ...item, read: true, readAt: new Date().toISOString() };
      return updated;
    }
    return item;
  }), []);
  if (!updated) return res.status(404).json({ message: 'Notification not found' });
  return res.json({ notification: updated });
});

router.post('/read-all', authenticateToken, (req, res) => {
  const now = new Date().toISOString();
  let changed = 0;
  store.updateCollection('notifications', (items) => items.map((item) => {
    if (item.userId === req.user.id && !item.read) {
      changed += 1;
      return { ...item, read: true, readAt: now };
    }
    return item;
  }), []);
  return res.json({ message: 'Notifications marked as read', changed });
});

// --- Device registration for push delivery ---------------------------------
router.post('/devices', authenticateToken, (req, res) => {
  const { pushToken, platform = 'android', deviceLabel = null } = req.body;
  if (!pushToken) return res.status(400).json({ message: 'pushToken is required' });

  store.updateCollection('devices', (devices) => {
    const others = devices.filter((device) => device.pushToken !== pushToken);
    others.push({
      userId: req.user.id,
      pushToken: String(pushToken),
      platform: String(platform),
      deviceLabel: deviceLabel ? String(deviceLabel) : null,
      registeredAt: new Date().toISOString(),
    });
    return others;
  }, []);

  store.appendAudit({
    actorId: req.user.id,
    actorRole: req.user.role,
    action: 'PUSH_TOKEN_REGISTERED',
    targetType: 'device',
    targetId: null,
    detail: String(platform),
  });

  return res.status(201).json({ message: 'Device registered for push notifications' });
});

router.delete('/devices/:pushToken', authenticateToken, (req, res) => {
  store.updateCollection('devices', (devices) => devices.filter(
    (device) => !(device.pushToken === req.params.pushToken && device.userId === req.user.id),
  ), []);
  return res.json({ message: 'Device removed' });
});

module.exports = router;
