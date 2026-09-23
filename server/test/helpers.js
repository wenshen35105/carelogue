// Test helpers: build App Store-shaped JWS transactions signed by the throwaway
// certificate chain in test/fixtures (generated once with openssl, valid for a
// century). Nothing here touches Apple's real certificates.

import { readFileSync } from 'node:fs';
import { createSign, createPrivateKey } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const FIXTURES = join(dirname(fileURLToPath(import.meta.url)), 'fixtures');

/** PEM file -> DER bytes. */
export function readDer(name) {
  const pem = readFileSync(join(FIXTURES, name), 'utf8');
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Buffer.from(body, 'base64');
}

/** PEM file -> the base64 body, the form x5c uses. */
export function readBase64(name) {
  return readDer(name).toString('base64');
}

export function readKey(name) {
  return createPrivateKey(readFileSync(join(FIXTURES, name), 'utf8'));
}

export function base64Url(buffer) {
  return Buffer.from(buffer).toString('base64url');
}

/** SHA-256 of a DER certificate, lowercase hex. */
export async function fingerprintOf(name) {
  const digest = await crypto.subtle.digest('SHA-256', readDer(name));
  return Buffer.from(digest).toString('hex');
}

/**
 * Signs a payload the way the App Store does: ES256, chain in x5c.
 * @param {object} payload
 * @param {{leaf?: string, chain?: string[], key?: string, alg?: string}} [options]
 */
export function signTransaction(payload, options = {}) {
  const chain = options.chain ?? ['leaf.pem', 'intermediate.pem', 'root.pem'];
  const header = { alg: options.alg ?? 'ES256', x5c: chain.map(readBase64) };
  const signingInput =
    `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}`;

  const signer = createSign('SHA256');
  signer.update(signingInput);
  const signature = signer.sign({
    key: readKey(options.key ?? 'leaf.key'),
    dsaEncoding: 'ieee-p1363', // raw r‖s, as JOSE wants
  });
  return `${signingInput}.${base64Url(signature)}`;
}

/** A transaction payload for an active subscription. */
export function activePayload(overrides = {}) {
  return {
    transactionId: '2000000000000001',
    originalTransactionId: '2000000000000001',
    bundleId: 'com.jiajinlinpersonalteam.Carelogue',
    productId: 'com.jiajinlinpersonalteam.Carelogue.plus.monthly',
    type: 'Auto-Renewable Subscription',
    purchaseDate: Date.now() - 1_000,
    expiresDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
    environment: 'Sandbox',
    ...overrides,
  };
}

/** In-memory stand-in for a Workers KV namespace. */
export function fakeKV() {
  const store = new Map();
  return {
    store,
    async get(key) {
      return store.has(key) ? store.get(key) : null;
    },
    async put(key, value) {
      store.set(key, value);
    },
  };
}
