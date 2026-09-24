// Carelogue's Worker: the explain relay (T26) plus the two policy pages.
//
// The relay's one job: take report text from a subscribed copy of the app,
// hand it to the AI provider, hand the reply back. It keeps no user database —
// the App Store transaction the app sends is verified on the spot — and it
// writes nothing down: no request bodies, no replies, no identifiers beyond
// the rate-limit counters, which hold only a hash and a number.
//
// The same Worker answers carelogue.ca/privacy and /terms, rendered from
// docs/legal/*.md. Two hostnames, one deployment: the routes in wrangler.toml
// decide which paths reach it, and this file dispatches on the path.
//
// The policy Markdown arrives as an argument rather than an import so this
// module stays plain JavaScript that `node --test` can exercise end to end;
// src/worker.js is the bundled entry that supplies it.

import { verifyJws } from './jws.js';
import { checkEntitlement, EntitlementError } from './subscription.js';
import { consumeAll } from './ratelimit.js';
import { complete, contentOf, UpstreamError } from './upstream.js';
import { buildPrompt, PromptError } from './prompt.js';
import { LEGAL_ROUTES, legalResponse } from './legal.js';

/**
 * Shortest credential the internal channel will accept — a typo'd or
 * half-filled secret must never open the relay to everyone.
 */
const MIN_INTERNAL_KEY_LENGTH = 24;

/**
 * What the internal channel counts as. One identity on purpose: every
 * internal device shares a single rate-limit bucket, so the ceiling applies
 * to the channel as a whole.
 */
const INTERNAL_ENTITLEMENT = {
  productId: 'internal',
  expiresDate: null,
  environment: 'Internal',
  originalTransactionId: 'internal-access',
};

const DEFAULTS = {
  PER_DEVICE_LIMIT: '40',
  PER_IP_LIMIT: '120',
  WINDOW_SECONDS: '3600',
  GRACE_MS: String(24 * 60 * 60 * 1000),
};

/**
 * @param {{privacy?: string, terms?: string}} documents  policy Markdown by name
 */
export function createWorker(documents = {}) {
  return {
    /**
     * @param {Request} request
     * @param {Record<string, any>} env
     */
    async fetch(request, env) {
      return handle(request, env, documents);
    },
  };
}

/**
 * @param {Request} request
 * @param {Record<string, any>} env
 * @param {{privacy?: string, terms?: string}} documents
 */
async function handle(request, env, documents) {
  const url = new URL(request.url);
  // Trailing slashes are the same page; everything else is case-sensitive.
  const path = url.pathname.length > 1 ? url.pathname.replace(/\/+$/, '') : url.pathname;

  const document = LEGAL_ROUTES[path];
  if (document) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return problem('method_not_allowed', 405);
    }
    const markdown = documents[document];
    if (!markdown) return problem('not_configured', 500);
    const response = legalResponse(markdown, document);
    return request.method === 'HEAD' ? new Response(null, response) : response;
  }

  if (request.method === 'GET' && path === '/v1/health') {
    return json({ ok: true });
  }
  if (path !== '/v1/explain') return problem('not_found', 404);
  if (request.method !== 'POST') return problem('method_not_allowed', 405);

  // 1. Who is asking: a signed App Store transaction, verified here — or,
  // for the internal channel (T30), the shared credential that stands in for
  // one while the app is not on sale yet.
  const token = bearer(request.headers.get('authorization'));
  if (!token) return problem('missing_subscription', 401);

  let entitlement;
  if (await isInternalCredential(token, env.INTERNAL_ACCESS_KEY)) {
    entitlement = INTERNAL_ENTITLEMENT;
  } else {
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

  // 3. What: an action plus its content and context. The prompt itself is
  // built here (T31) — the device never sends prose.
  if (!env.DEEPINFRA_API_KEY || !env.DEEPINFRA_MODEL) return problem('not_configured', 500);

  let body;
  try {
    body = await request.json();
  } catch {
    return problem('bad_request', 400);
  }

  let prompt;
  try {
    prompt = buildPrompt(body);
  } catch (error) {
    if (error instanceof PromptError) {
      return problem(error.reason, error.reason === 'too_long' ? 413 : 400);
    }
    return problem('bad_request', 400);
  }

  try {
    const response = await complete(
      { ...prompt, stream: body.stream === true },
      { apiKey: env.DEEPINFRA_API_KEY, model: env.DEEPINFRA_MODEL, endpoint: env.PROVIDER_ENDPOINT },
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
}

/**
 * The internal channel (T30): Debug builds of the app carry a shared
 * credential instead of an App Store transaction, so the whole chain can be
 * exercised before the subscription exists. Off unless INTERNAL_ACCESS_KEY is
 * set, and deleted before the public launch (`wrangler secret delete`).
 *
 * Digests are compared rather than the strings themselves: both sides are
 * hashed first, so how far the comparison gets says nothing about the secret.
 * @param {string} token
 * @param {unknown} secret
 */
async function isInternalCredential(token, secret) {
  if (typeof secret !== 'string' || secret.length < MIN_INTERNAL_KEY_LENGTH) return false;
  const [offered, expected] = await Promise.all([hash(token), hash(secret)]);
  return offered === expected;
}

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
