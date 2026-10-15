'use strict';

/**
 * Secure registration and authentication (core feature: section 3.9).
 * Minimal personal information is collected (section 3.12 VII): the email is
 * only used as the login identifier and is never exposed to other students.
 */

const express = require('express');
const {
  ROLES,
  hashPassword,
  verifyPassword,
  signToken,
  publicUser,
  authenticateToken,
  roleForEmail,
} = require('../security');
const store = require('../store');

const router = express.Router();

function normaliseEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function validateCredentials(email, password) {
  const problems = [];
  if (!email) problems.push('Email is required');
  else if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) problems.push('Email address is not valid');
  if (!password) problems.push('Password is required');
  else if (String(password).length < 8) problems.push('Password must be at least 8 characters');
  return problems;
}

router.post('/register', async (req, res) => {
  const email = normaliseEmail(req.body.email);
  const password = String(req.body.password || '');
  const displayName = String(req.body.displayName || '').trim() || null;

  const problems = validateCredentials(email, password);
  if (problems.length) return res.status(400).json({ message: problems.join('. ') });

  const users = store.readCollection('users', []);
  if (users.some((user) => user.email === email)) {
    return res.status(409).json({ message: 'An account already exists for this email' });
  }

  const user = {
    id: `usr_${store.nextId()}`,
    email,
    displayName,
    password: await hashPassword(password),
    role: roleForEmail(email),
    createdAt: new Date().toISOString(),
  };

  users.push(user);
  store.writeCollection('users', users);
  store.appendAudit({ actorId: user.id, actorRole: user.role, action: 'ACCOUNT_CREATED', targetType: 'user', targetId: user.id });

  return res.status(201).json({ message: 'Account created', user: publicUser(user) });
});

router.post('/login', async (req, res) => {
  const email = normaliseEmail(req.body.email);
  const password = String(req.body.password || '');

  const users = store.readCollection('users', []);
  const user = users.find((candidate) => candidate.email === email);
  if (!user) return res.status(401).json({ message: 'Invalid credentials' });

  const ok = await verifyPassword(password, user.password);
  if (!ok) {
    store.appendAudit({ actorId: user.id, actorRole: user.role, action: 'LOGIN_FAILED', targetType: 'user', targetId: user.id });
    return res.status(401).json({ message: 'Invalid credentials' });
  }

  // Accounts created before roles existed default to the student role.
  if (!user.role) {
    user.role = roleForEmail(user.email);
    store.writeCollection('users', users);
  }

  store.appendAudit({ actorId: user.id, actorRole: user.role, action: 'LOGIN_SUCCEEDED', targetType: 'user', targetId: user.id });

  return res.json({ token: signToken(user), user: publicUser(user) });
});

router.get('/me', authenticateToken, (req, res) => {
  const users = store.readCollection('users', []);
  const user = users.find((candidate) => candidate.id === req.user.id);
  if (!user) return res.status(404).json({ message: 'Account not found' });
  return res.json({ user: publicUser(user) });
});

router.get('/roles', (_req, res) => res.json({ roles: Object.values(ROLES) }));

module.exports = router;
