// Carelogue's explain relay (T26).
//
// One job: take report text from a subscribed copy of the app, hand it to the
// AI provider, hand the reply back. It keeps no user database — the App Store
// transaction the app sends is verified on the spot — and it writes nothing
// down: no request bodies, no replies, no identifiers beyond the rate-limit
// counters, which hold only a hash and a number.

import { verifyJws } from './jws.js';
import { checkEntitlement, EntitlementError } from './subscription.js';
import { consumeAll } from './ratelimit.js';
import { complete, contentOf, UpstreamError } from './upstream.js';

/** Bounds the prompt so one caller cannot run up a bill on a single request. */
const MAX_SYSTEM_CHARACTERS = 8_000;
const MAX_USER_CHARACTERS = 16_000;

const DEFAULTS = {
  PER_DEVICE_LIMIT: '40',
  PER_IP_LIMIT: '120',
  WINDOW_SECONDS: '3600',
  GRACE_MS: String(24 * 60 * 60 * 1000),
};

export default {
  /**
   * @param {Request} request
   * @param {Record<string, any>} env
   */
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/v1/health') {
      return json({ ok: true });
    }
    if (url.pathname !== '/v1/explain') return problem('not_found', 404);
    if (request.method !== 'POST') return problem('method_not_allowed', 405);

    // 1. Who is asking: a signed App Store transaction, verified here.
    const token = bearer(request.headers.get('authorization'));
    if (!token) return problem('missing_subscription', 401);

    let entitlement;
    try {
      const payload = await verifyJws(token, env.APPLE_ROOT_CA_G3_SHA256);
      entitlement = checkEntitlement(payload, {
        bundleId: env.BUNDLE_ID,
        productIds: (env.PRODUCT_IDS ?? '').split(',').map((id) => id.trim()).filter(Boolean),
        allowSandbox: env.ALLOW_SANDBOX === '1',
        graceMs: Number(env.GRACE_MS ?? DEFAULTS.GRACE_MS),
      });
    } catch (error) {
      if (error instanceof EntitlementError) return problem(error.reason, 402);
      return problem('invalid_subscription', 401);
    }

    // 2. How much: a ceiling per subscriber and per address.
    const subscriber = await hash(entitlement.originalTransactionId ?? token.slice(-64));
    const address = await hash(request.headers.get('cf-connecting-ip') ?? 'unknown');
    const window = Number(env.WINDOW_SECONDS ?? DEFAULTS.WINDOW_SECONDS);
    const limited = await consumeAll(env.RATE_LIMIT, [
      { key: `sub:${subscriber}`, limit: Number(env.PER_DEVICE_LIMIT ?? DEFAULTS.PER_DEVICE_LIMIT), windowSeconds: window },
      { key: `ip:${address}`, limit: Number(env.PER_IP_LIMIT ?? DEFAULTS.PER_IP_LIMIT), windowSeconds: window },
    ]);
    if (!limited.allowed) {
      return problem('rate_limited', 429, {
        'retry-after': String(Math.max(1, Math.ceil((limited.resetAt - Date.now()) / 1000))),
      });
    }

    // 3. What: the prompt the device built, forwarded as-is.
    if (!env.DEEPINFRA_API_KEY || !env.DEEPINFRA_MODEL) return problem('not_configured', 500);

    let body;
    try {
      body = await request.json();
    } catch {
      return problem('bad_request', 400);
    }
    if (typeof body?.system !== 'string' || typeof body?.user !== 'string') {
      return problem('bad_request', 400);
    }
    if (body.system.length > MAX_SYSTEM_CHARACTERS || body.user.length > MAX_USER_CHARACTERS) {
      return problem('too_long', 413);
    }

    try {
      const response = await complete(
        { system: body.system, user: body.user, json: body.json === true, stream: body.stream === true },
        { apiKey: env.DEEPINFRA_API_KEY, model: env.DEEPINFRA_MODEL },
      );

      if (body.stream === true) {
        // Straight passthrough: the bytes are never buffered here.
        return new Response(response.body, {
          status: 200,
          headers: {
            'content-type': response.headers.get('content-type') ?? 'text/event-stream',
            'cache-control': 'no-store',
          },
        });
      }
      return json({ content: contentOf(await response.json()), model: env.DEEPINFRA_MODEL });
    } catch (error) {
      if (error instanceof UpstreamError) return problem(error.reason, error.status);
      return problem('server_error', 500);
    }
  },
};

/** @param {string | null} header */
function bearer(header) {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

/** SHA-256, hex — so rate-limit keys hold no recoverable identifier. */
async function hash(value) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest).slice(0, 16), (b) => b.toString(16).padStart(2, '0')).join('');
}

function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store', ...headers },
  });
}

/** Errors are a stable machine-readable code; the app owns the wording. */
function problem(code, status, headers = {}) {
  return json({ error: code }, status, headers);
}
