// Fixed-window rate limiting on Workers KV.
//
// Deliberately simple: the point is a ceiling on runaway cost (a stuck retry
// loop, a leaked build), not fairness. KV is eventually consistent, so a burst
// spread across colos can overshoot slightly — acceptable for a ceiling.

/**
 * @typedef {{get: (key: string, type?: string) => Promise<any>, put: (key: string, value: string, options?: object) => Promise<void>}} KVNamespace
 */

/**
 * Counts one request against `key`.
 *
 * @param {KVNamespace | undefined} kv  when absent, limiting is skipped
 * @param {string} key
 * @param {number} limit    requests allowed per window
 * @param {number} windowSeconds
 * @param {number} now epoch ms
 * @returns {Promise<{allowed: boolean, used: number, resetAt: number}>}
 */
export async function consume(kv, key, limit, windowSeconds, now = Date.now()) {
  if (!kv) return { allowed: true, used: 0, resetAt: now };

  const windowStart = Math.floor(now / (windowSeconds * 1000)) * windowSeconds * 1000;
  const bucket = `rl:${key}:${windowStart}`;
  const used = Number((await kv.get(bucket)) ?? 0);
  const resetAt = windowStart + windowSeconds * 1000;

  if (used >= limit) return { allowed: false, used, resetAt };

  // TTL is the rest of the window plus KV's 60s minimum.
  await kv.put(bucket, String(used + 1), {
    expirationTtl: Math.max(60, Math.ceil((resetAt - now) / 1000) + 60),
  });
  return { allowed: true, used: used + 1, resetAt };
}

/**
 * Applies every limit in order and returns the first one that trips.
 *
 * @param {KVNamespace | undefined} kv
 * @param {{key: string, limit: number, windowSeconds: number}[]} limits
 * @param {number} now
 */
export async function consumeAll(kv, limits, now = Date.now()) {
  for (const limit of limits) {
    const result = await consume(kv, limit.key, limit.limit, limit.windowSeconds, now);
    if (!result.allowed) return { allowed: false, resetAt: result.resetAt, key: limit.key };
  }
  return { allowed: true };
}
