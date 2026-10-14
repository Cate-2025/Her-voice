'use strict';

/**
 * Privacy-conscious notification service (sections 3.6 and 3.11).
 *
 * Titles are deliberately generic so that nothing sensitive appears on a lock
 * screen. The detailed message is only readable after the student authenticates
 * inside the application.
 *
 * Delivery channel selection:
 *   - PUSH  when the student's device has registered a push token
 *   - SMS   fallback for critical updates when no device is registered
 *
 * The SMS gateway itself is not wired to a commercial provider in the
 * prototype; the outgoing message is written to the server log instead.
 */

const store = require('./store');
const {
  NOTIFICATION_CATEGORIES,
  PRIVACY_SAFE_NOTIFICATION_TITLES,
} = require('./domain');

const NEUTRAL_BODY =
  'There is a new update on your HERVOICE account. Open the application and authenticate to read it.';

function resolveChannel(userId) {
  const devices = store.readCollection('devices', []);
  const hasDevice = devices.some((device) => device.userId === userId && device.pushToken);
  return hasDevice ? 'PUSH' : 'SMS_FALLBACK';
}

function createNotification({
  userId,
  category = NOTIFICATION_CATEGORIES.CASE_UPDATE,
  caseId = null,
  caseReference = null,
  body = NEUTRAL_BODY,
  critical = false,
}) {
  const channel = critical ? resolveChannel(userId) : 'PUSH';

  const notification = {
    id: `ntf_${store.nextId()}`,
    userId: userId || null,
    category,
    title: PRIVACY_SAFE_NOTIFICATION_TITLES[category] || PRIVACY_SAFE_NOTIFICATION_TITLES.SYSTEM,
    body,
    caseId,
    caseReference,
    read: false,
    channel,
    createdAt: new Date().toISOString(),
  };

  store.updateCollection('notifications', (items) => {
    items.push(notification);
    return items.slice(-5000);
  }, []);

  if (channel === 'SMS_FALLBACK') {
    console.warn(
      `[notify] SMS fallback queued for user ${userId}: "${notification.title}" `
      + '(payload intentionally contains no case detail).',
    );
  }

  return notification;
}

function notifyStaff(category, payload) {
  const users = store.readCollection('users', []);
  const staff = users.filter((user) => user.role && user.role !== 'STUDENT');
  return staff.map((member) => createNotification({ userId: member.id, category, ...payload }));
}

function listForUser(userId) {
  return store
    .readCollection('notifications', [])
    .filter((notification) => notification.userId === userId)
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

module.exports = { createNotification, notifyStaff, listForUser, NEUTRAL_BODY };
