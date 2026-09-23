// What counts as an active Carelogue Plus subscription.
//
// The App Store signs every transaction; the app sends the newest one with
// each request and this decides whether it still entitles the caller. There is
// no user database here on purpose — the signed transaction is the whole
// record (spec §11: stateless verification, no accounts).

/** Apple's `type` for an auto-renewing subscription. */
const AUTO_RENEWABLE = 'Auto-Renewable Subscription';

export class EntitlementError extends Error {
  /** @param {string} reason short machine-readable reason */
  constructor(reason) {
    super(`entitlement: ${reason}`);
    this.reason = reason;
  }
}

/**
 * @typedef {object} EntitlementRules
 * @property {string} bundleId
 * @property {string[]} productIds
 * @property {boolean} allowSandbox  sandbox transactions during internal testing
 * @property {number} [graceMs]      tolerance for clock skew / renewal lag
 */

/**
 * Checks a decoded JWSTransaction payload.
 * @param {Record<string, any>} payload
 * @param {EntitlementRules} rules
 * @param {number} now epoch ms
 */
export function checkEntitlement(payload, rules, now = Date.now()) {
  if (payload.bundleId !== rules.bundleId) throw new EntitlementError('wrong_bundle');
  if (!rules.productIds.includes(payload.productId)) throw new EntitlementError('wrong_product');
  if (payload.type && payload.type !== AUTO_RENEWABLE) throw new EntitlementError('wrong_type');

  if (payload.environment === 'Sandbox' && !rules.allowSandbox) {
    throw new EntitlementError('sandbox_not_allowed');
  }
  if (payload.revocationDate) throw new EntitlementError('revoked');

  const grace = rules.graceMs ?? 0;
  if (typeof payload.expiresDate !== 'number') throw new EntitlementError('missing_expiry');
  if (payload.expiresDate + grace <= now) throw new EntitlementError('expired');

  return {
    productId: payload.productId,
    expiresDate: payload.expiresDate,
    environment: payload.environment ?? 'Production',
    // Stable per subscriber, and the only identifier this service ever holds —
    // in memory, for the length of one request, to key the rate limiter.
    originalTransactionId: payload.originalTransactionId ?? null,
  };
}
