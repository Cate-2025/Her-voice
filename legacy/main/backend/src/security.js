'use strict';

/**
 * Authentication, role-based access control and password handling.
 * Implements items I, II and VI of section 3.12 of the concept paper.
 */

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret_change_me';
const TOKEN_TTL = '7d';

const ROLES = Object.freeze({
  STUDENT: 'STUDENT',
  OFFICER: 'OFFICER', // Safeguarding officer / counsellor
  ADMIN: 'ADMIN', // Institutional administrator
});

const STAFF_ROLES = [ROLES.OFFICER, ROLES.ADMIN];

const ADMIN_EMAILS = String(process.env.ADMIN_EMAILS || '')
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);

const OFFICER_EMAILS = String(process.env.OFFICER_EMAILS || '')
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);

function hashPassword(plain) {
  return bcrypt.hash(plain, 10);
}

function verifyPassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role, name: user.displayName || null },
    JWT_SECRET,
    { expiresIn: TOKEN_TTL },
  );
}

/** Public shape of a user - never leaks the password hash. */
function publicUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName || null,
    role: user.role || ROLES.STUDENT,
    createdAt: user.createdAt || null,
  };
}

function authenticateToken(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'Token required' });

  return jwt.verify(token, JWT_SECRET, (err, payload) => {
    if (err) return res.status(403).json({ message: 'Invalid or expired token' });
    req.user = { id: payload.sub, email: payload.email, role: payload.role, name: payload.name };
    return next();
  });
}

/** Only safeguarding officers and administrators may view institution-wide data. */
function requireStaff(req, res, next) {
  if (!req.user || !STAFF_ROLES.includes(req.user.role)) {
    return res.status(403).json({ message: 'Authorised institutional personnel only' });
  }
  return next();
}

/** Administrative actions (pattern alerts, audit log, case decisions). */
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== ROLES.ADMIN) {
    return res.status(403).json({ message: 'Administrator role required' });
  }
  return next();
}

/** Resolves the role for a brand new account from the configured allow-lists. */
function roleForEmail(email) {
  const normalised = String(email || '').toLowerCase();
  if (ADMIN_EMAILS.includes(normalised)) return ROLES.ADMIN;
  if (OFFICER_EMAILS.includes(normalised)) return ROLES.OFFICER;
  return ROLES.STUDENT;
}

module.exports = {
  ROLES,
  STAFF_ROLES,
  hashPassword,
  verifyPassword,
  signToken,
  publicUser,
  authenticateToken,
  requireStaff,
  requireAdmin,
  roleForEmail,
};
