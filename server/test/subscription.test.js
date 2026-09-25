import test from 'node:test';
import assert from 'node:assert/strict';

import { checkEntitlement, EntitlementError } from '../src/subscription.js';
import { consume, consumeAll } from '../src/ratelimit.js';
import { activePayload, fakeKV } from './helpers.js';

const rules = {
  bundleId: 'ca.carelogue.app',
  productIds: ['ca.carelogue.app.plus.monthly'],
  allowSandbox: true,
};

test('accepts an active subscription', () => {
  const entitlement = checkEntitlement(activePayload(), rules);
  assert.equal(entitlement.productId, rules.productIds[0]);
  assert.equal(entitlement.originalTransactionId, '2000000000000001');
});

test('rejects another app, another product, or another type', () => {
  for (const [override, reason] of [
    [{ bundleId: 'com.example.other' }, 'wrong_bundle'],
    [{ productId: 'com.example.other.monthly' }, 'wrong_product'],
    [{ type: 'Non-Consumable' }, 'wrong_type'],
  ]) {
    assert.throws(() => checkEntitlement(activePayload(override), rules), (error) => {
      assert.ok(error instanceof EntitlementError);
      assert.equal(error.reason, reason);
      return true;
    });
  }
});

test('rejects expired and revoked transactions', () => {
  const expired = activePayload({ expiresDate: Date.now() - 1 });
  assert.throws(() => checkEntitlement(expired, rules), /expired/);

  const revoked = activePayload({ revocationDate: Date.now() - 1000 });
  assert.throws(() => checkEntitlement(revoked, rules), /revoked/);
});

test('a grace period keeps a just-lapsed renewal working', () => {
  const justLapsed = activePayload({ expiresDate: Date.now() - 60_000 });
  assert.throws(() => checkEntitlement(justLapsed, rules), /expired/);
  assert.doesNotThrow(() => checkEntitlement(justLapsed, { ...rules, graceMs: 3_600_000 }));
});

test('sandbox transactions are refused unless explicitly allowed', () => {
  const sandbox = activePayload({ environment: 'Sandbox' });
  assert.throws(
    () => checkEntitlement(sandbox, { ...rules, allowSandbox: false }),
    /sandbox_not_allowed/,
  );
});

test('rate limiter counts within a window and resets after it', async () => {
  const kv = fakeKV();
  const now = 1_000_000_000_000;
  for (let i = 1; i <= 3; i++) {
    const result = await consume(kv, 'sub:abc', 3, 3600, now);
    assert.equal(result.allowed, true, `request ${i} should be allowed`);
  }
  assert.equal((await consume(kv, 'sub:abc', 3, 3600, now)).allowed, false);

  // Next window, fresh budget.
  const later = now + 3600 * 1000;
  assert.equal((await consume(kv, 'sub:abc', 3, 3600, later)).allowed, true);
});

test('without a KV binding nothing is limited', async () => {
  const result = await consume(undefined, 'sub:abc', 0, 3600);
  assert.equal(result.allowed, true);
});

test('consumeAll reports the first limit that trips', async () => {
  const kv = fakeKV();
  const now = 1_000_000_000_000;
  const limits = [
    { key: 'sub:abc', limit: 1, windowSeconds: 3600 },
    { key: 'ip:1.2.3.4', limit: 5, windowSeconds: 3600 },
  ];
  assert.equal((await consumeAll(kv, limits, now)).allowed, true);
  const blocked = await consumeAll(kv, limits, now);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.key, 'sub:abc');
});
