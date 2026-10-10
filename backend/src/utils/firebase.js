/**
 * Verifies Firebase Auth ID tokens (RS256 JWTs) with Node's built-in crypto. No firebase-admin and no
 * service-account file needed: Google publishes the signing certificates publicly.
 * Checks: signature, alg, aud == project id, iss == https://securetoken.google.com/<project>, exp, iat, sub.
 */
const crypto = require('node:crypto');

const CERT_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
let cache = { certs: null, expires: 0 };

async function fetchGoogleCerts() {
  if (cache.certs && Date.now() < cache.expires) return cache.certs;
  const res = await fetch(CERT_URL);
  if (!res.ok) throw new Error(`Could not load Firebase certificates (${res.status})`);
  const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get('cache-control') || '')?.[1] || 3600);
  cache = { certs: await res.json(), expires: Date.now() + maxAge * 1000 };
  return cache.certs;
}

const b64url = (s) => Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64');

async function verifyFirebaseIdToken(token, { projectId, getCerts = fetchGoogleCerts, nowMs = Date.now() }) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) throw new Error('Malformed token');

  let header, payload;
  try {
    header = JSON.parse(b64url(parts[0]).toString('utf8'));
    payload = JSON.parse(b64url(parts[1]).toString('utf8'));
  } catch {
    throw new Error('Malformed token');
  }
  if (header.alg !== 'RS256' || !header.kid) throw new Error('Unsupported token algorithm');

  const certs = await getCerts();
  const key = certs[header.kid];
  if (!key) throw new Error('Unknown signing key');

  const valid = crypto.createVerify('RSA-SHA256').update(`${parts[0]}.${parts[1]}`).verify(key, b64url(parts[2]));
  if (!valid) throw new Error('Bad signature');

  const nowSec = Math.floor(nowMs / 1000);
  if (payload.aud !== projectId) throw new Error('Wrong audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Wrong issuer');
  if (typeof payload.sub !== 'string' || !payload.sub) throw new Error('Missing subject');
  if (!(payload.exp > nowSec)) throw new Error('Token expired');
  if (!(payload.iat <= nowSec + 300)) throw new Error('Token issued in the future');
  return payload;
}

module.exports = { verifyFirebaseIdToken };
