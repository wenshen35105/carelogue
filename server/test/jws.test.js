import test from 'node:test';
import assert from 'node:assert/strict';

import { verifyJws, decodeJws } from '../src/jws.js';
import { parseCertificate, verifyChain } from '../src/x509.js';
import {
  signTransaction,
  activePayload,
  fingerprintOf,
  readDer,
  base64Url,
} from './helpers.js';

const rootFingerprint = await fingerprintOf('root.pem');

test('accepts a transaction signed by the pinned chain', async () => {
  const payload = activePayload();
  const verified = await verifyJws(signTransaction(payload), rootFingerprint);
  assert.equal(verified.transactionId, payload.transactionId);
  assert.equal(verified.productId, payload.productId);
});

test('rejects a tampered payload', async () => {
  const token = signTransaction(activePayload());
  const [header, , signature] = token.split('.');
  const forged = base64Url(JSON.stringify(activePayload({ productId: 'free.forever' })));
  await assert.rejects(
    () => verifyJws(`${header}.${forged}.${signature}`, rootFingerprint),
    /bad signature/,
  );
});

test('rejects a chain that does not end at the pinned root', async () => {
  const token = signTransaction(activePayload());
  await assert.rejects(() => verifyJws(token, 'f'.repeat(64)), /pinned Apple root/);
});

test('rejects a chain with the intermediate left out', async () => {
  const token = signTransaction(activePayload(), { chain: ['leaf.pem', 'root.pem'] });
  await assert.rejects(() => verifyJws(token, rootFingerprint), /broken issuer chain/);
});

test('rejects a certificate outside its validity window', async () => {
  const chain = ['expired.pem', 'intermediate.pem', 'root.pem'].map((name) =>
    parseCertificate(readDer(name)),
  );
  await assert.rejects(() => verifyChain(chain, rootFingerprint), /validity window/);
});

test('rejects an unsupported algorithm', async () => {
  const token = signTransaction(activePayload(), { alg: 'HS256' });
  await assert.rejects(() => verifyJws(token, rootFingerprint), /unsupported algorithm/);
});

test('rejects a token with no chain at all', async () => {
  const token = signTransaction(activePayload());
  const [, payload, signature] = token.split('.');
  const header = base64Url(JSON.stringify({ alg: 'ES256' }));
  await assert.rejects(
    () => verifyJws(`${header}.${payload}.${signature}`, rootFingerprint),
    /missing certificate chain/,
  );
});

test('decodeJws reads the payload without verifying anything', () => {
  const payload = activePayload();
  const { header, payload: decoded } = decodeJws(signTransaction(payload));
  assert.equal(header.alg, 'ES256');
  assert.equal(decoded.bundleId, payload.bundleId);
});
