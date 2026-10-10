const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { verifyFirebaseIdToken } = require('../src/utils/firebase');

const PROJECT = 'galla-pro-test';
const NOW = 1_800_000_000_000;
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const other = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = publicKey.export({ type: 'spki', format: 'pem' });
const getCerts = async () => ({ kid1: pem });
const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');

function sign(payload, { key = privateKey, header = { alg: 'RS256', kid: 'kid1', typ: 'JWT' } } = {}) {
  const body = `${b64(header)}.${b64(payload)}`;
  return `${body}.${crypto.createSign('RSA-SHA256').update(body).sign(key).toString('base64url')}`;
}
const good = { aud: PROJECT, iss: `https://securetoken.google.com/${PROJECT}`, sub: 'uid123', email: 'a@b.com', iat: NOW / 1000 - 60, exp: NOW / 1000 + 3600 };
const verify = (t) => verifyFirebaseIdToken(t, { projectId: PROJECT, getCerts, nowMs: NOW });

test('accepts a valid token and returns its claims', async () => {
  const c = await verify(sign(good));
  assert.equal(c.sub, 'uid123');
  assert.equal(c.email, 'a@b.com');
});
test('rejects wrong signature', async () => assert.rejects(verify(sign(good, { key: other.privateKey })), /signature/i));
test('rejects expired token', async () => assert.rejects(verify(sign({ ...good, exp: NOW / 1000 - 1 })), /expired/i));
test('rejects wrong audience', async () => assert.rejects(verify(sign({ ...good, aud: 'other-project' })), /audience/i));
test('rejects wrong issuer', async () => assert.rejects(verify(sign({ ...good, iss: 'https://evil.example' })), /issuer/i));
test('rejects missing subject', async () => assert.rejects(verify(sign({ ...good, sub: '' })), /subject/i));
test('rejects token from the future', async () => assert.rejects(verify(sign({ ...good, iat: NOW / 1000 + 9999 })), /future/i));
test('rejects unknown key id', async () => assert.rejects(verify(sign(good, { header: { alg: 'RS256', kid: 'nope' } })), /key/i));
test('rejects alg none / HS256 downgrade', async () => {
  await assert.rejects(verify(`${b64({ alg: 'none', kid: 'kid1' })}.${b64(good)}.`), /algorithm|Malformed/i);
  const hs = `${b64({ alg: 'HS256', kid: 'kid1' })}.${b64(good)}.${b64('x')}`;
  await assert.rejects(verify(hs), /algorithm/i);
});
test('rejects garbage', async () => {
  await assert.rejects(verify('not-a-jwt'), /Malformed/);
  await assert.rejects(verify(''), /Malformed/);
});
