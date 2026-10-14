'use strict';

/**
 * Tiny JSON-file persistence layer for the HERVOICE prototype.
 *
 * A full database is out of scope for the 8-9 week prototype, but the
 * collection names mirror the tables described in section 7.1 of the concept
 * paper (users, reports, cases, evidence metadata, audit information) so the
 * layer can be swapped for a real database later without touching the routes.
 */

const fs = require('fs');
const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');
const DATA_DIR = path.join(BACKEND_ROOT, 'data');
const UPLOAD_DIR = path.join(BACKEND_ROOT, 'uploads');

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function ensureStorage() {
  ensureDir(DATA_DIR);
  ensureDir(UPLOAD_DIR);
}

function fileFor(collection) {
  return path.join(DATA_DIR, `${collection}.json`);
}

/**
 * Reads a collection. The legacy location (backend/<collection>.json) is still
 * honoured so that data created by the first prototype is not lost.
 */
function readCollection(collection, fallback = []) {
  ensureStorage();
  const target = fileFor(collection);
  const legacy = path.join(BACKEND_ROOT, `${collection}.json`);
  const source = fs.existsSync(target) ? target : (fs.existsSync(legacy) ? legacy : null);
  if (!source) return fallback;
  try {
    const parsed = JSON.parse(fs.readFileSync(source, 'utf8') || 'null');
    return parsed === null ? fallback : parsed;
  } catch (err) {
    console.error(`[store] Could not parse ${collection}.json: ${err.message}`);
    return fallback;
  }
}

function writeCollection(collection, value) {
  ensureStorage();
  fs.writeFileSync(fileFor(collection), JSON.stringify(value, null, 2), 'utf8');
}

/** Read-modify-write helper used by the route modules. */
function updateCollection(collection, mutator, fallback = []) {
  const next = mutator(readCollection(collection, fallback));
  writeCollection(collection, next);
  return next;
}

function nextId() {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

function saveEvidenceFile(evidenceId, originalName, buffer) {
  ensureStorage();
  const safeName = String(originalName || 'evidence.bin')
    .replace(/[^A-Za-z0-9._-]/g, '_')
    .slice(-80);
  const storedName = `${evidenceId}__${safeName}`;
  const absolutePath = path.join(UPLOAD_DIR, storedName);
  fs.writeFileSync(absolutePath, buffer);
  return { storedName, absolutePath };
}

function deleteEvidenceFile(storedName) {
  const absolutePath = path.join(UPLOAD_DIR, storedName);
  if (fs.existsSync(absolutePath)) fs.unlinkSync(absolutePath);
}

function evidenceAbsolutePath(storedName) {
  const resolved = path.resolve(UPLOAD_DIR, String(storedName));
  const root = path.resolve(UPLOAD_DIR);
  if (!resolved.startsWith(root)) throw new Error('Invalid evidence path');
  return resolved;
}

/** Append-only audit trail for authorised administrative actions (section 3.12). */
function appendAudit(entry) {
  const record = {
    id: nextId(),
    at: new Date().toISOString(),
    actorId: entry.actorId || null,
    actorRole: entry.actorRole || null,
    action: entry.action,
    targetType: entry.targetType || null,
    targetId: entry.targetId || null,
    detail: entry.detail || null,
  };
  updateCollection('audit', (entries) => {
    entries.push(record);
    return entries.slice(-2000);
  }, []);
  return record;
}

module.exports = {
  BACKEND_ROOT,
  DATA_DIR,
  UPLOAD_DIR,
  ensureStorage,
  readCollection,
  writeCollection,
  updateCollection,
  nextId,
  saveEvidenceFile,
  deleteEvidenceFile,
  evidenceAbsolutePath,
  appendAudit,
};
