import test from 'node:test';
import assert from 'node:assert/strict';

import { createWorker } from '../src/index.js';
import { signTransaction, activePayload, fingerprintOf, fakeKV } from './helpers.js';

const rootFingerprint = await fingerprintOf('root.pem');

// The relay's own routes need no policy documents; legal.test.js covers those.
const worker = createWorker({});

function baseEnv(overrides = {}) {
  return {
    BUNDLE_ID: 'com.jiajinlinpersonalteam.Carelogue',
    PRODUCT_IDS: 'com.jiajinlinpersonalteam.Carelogue.plus.monthly',
    APPLE_ROOT_CA_G3_SHA256: rootFingerprint,
    ALLOW_SANDBOX: '1',
    DEEPINFRA_API_KEY: 'test-key',
    DEEPINFRA_MODEL: 'test/model',
    ...overrides,
  };
}

function explainRequest(token, body = { system: 'you explain reports', user: 'Hb 112 g/L' }) {
  return new Request('https://api.carelogue.ca/v1/explain', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      'cf-connecting-ip': '203.0.113.7',
    },
    body: JSON.stringify(body),
  });
}

/** Replaces global fetch for one call and records what the upstream saw. */
function stubUpstream(response) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init, body: JSON.parse(init.body) });
    return response();
  };
  return {
    calls,
    restore() {
      globalThis.fetch = original;
    },
  };
}

const upstreamReply = (content) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });

test('health check needs no subscription', async () => {
  const response = await worker.fetch(new Request('https://api.carelogue.ca/v1/health'), baseEnv());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
});

test('forwards the prompt and returns the model reply', async () => {
  const upstream = stubUpstream(() => upstreamReply('血红蛋白略低，属于常见情况。'));
  try {
    const response = await worker.fetch(
      explainRequest(signTransaction(activePayload()), {
        system: 'you explain reports',
        user: 'Hb 112 g/L',
        json: true,
      }),
      baseEnv(),
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      content: '血红蛋白略低，属于常见情况。',
      model: 'test/model',
    });

    assert.equal(upstream.calls.length, 1);
    const sent = upstream.calls[0].body;
    assert.equal(sent.model, 'test/model');
    assert.equal(sent.messages[0].content, 'you explain reports');
    assert.equal(sent.messages[1].content, 'Hb 112 g/L');
    assert.deepEqual(sent.response_format, { type: 'json_object' });
    assert.equal(upstream.calls[0].init.headers.authorization, 'Bearer test-key');
  } finally {
    upstream.restore();
  }
});

test('refuses a request with no transaction', async () => {
  const response = await worker.fetch(explainRequest(null), baseEnv());
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'missing_subscription' });
});

test('refuses a transaction signed by someone else', async () => {
  const response = await worker.fetch(
    explainRequest(signTransaction(activePayload())),
    baseEnv({ APPLE_ROOT_CA_G3_SHA256: 'f'.repeat(64) }),
  );
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'invalid_subscription' });
});

test('refuses an expired subscription with a distinct code', async () => {
  const expired = signTransaction(activePayload({ expiresDate: Date.now() - 10 * 24 * 3600 * 1000 }));
  const response = await worker.fetch(explainRequest(expired), baseEnv());
  assert.equal(response.status, 402);
  assert.deepEqual(await response.json(), { error: 'expired' });
});

test('refuses sandbox transactions once ALLOW_SANDBOX is off', async () => {
  const token = signTransaction(activePayload({ environment: 'Sandbox' }));
  const response = await worker.fetch(explainRequest(token), baseEnv({ ALLOW_SANDBOX: '0' }));
  assert.equal(response.status, 402);
  assert.deepEqual(await response.json(), { error: 'sandbox_not_allowed' });
});

test('an over-long report is refused before the provider is called', async () => {
  const upstream = stubUpstream(() => upstreamReply('never reached'));
  try {
    const response = await worker.fetch(
      explainRequest(signTransaction(activePayload()), {
        system: 'short',
        user: 'x'.repeat(16_001),
      }),
      baseEnv(),
    );
    assert.equal(response.status, 413);
    assert.equal(upstream.calls.length, 0);
  } finally {
    upstream.restore();
  }
});

test('the per-subscriber ceiling stops the next request', async () => {
  const upstream = stubUpstream(() => upstreamReply('ok'));
  try {
    const env = baseEnv({ RATE_LIMIT: fakeKV(), PER_DEVICE_LIMIT: '2', PER_IP_LIMIT: '100' });
    const token = signTransaction(activePayload());
    for (let i = 0; i < 2; i++) {
      assert.equal((await worker.fetch(explainRequest(token), env)).status, 200);
    }
    const blocked = await worker.fetch(explainRequest(token), env);
    assert.equal(blocked.status, 429);
    assert.ok(Number(blocked.headers.get('retry-after')) > 0);
    assert.equal(upstream.calls.length, 2, 'the blocked request never reached the provider');
  } finally {
    upstream.restore();
  }
});

test('provider failures are mapped, never forwarded verbatim', async () => {
  const cases = [
    [401, 502, 'provider_auth'],
    [402, 502, 'provider_balance'],
    [429, 429, 'provider_busy'],
    [500, 502, 'provider_error'],
  ];
  for (const [upstreamStatus, expectedStatus, expectedCode] of cases) {
    const upstream = stubUpstream(
      () => new Response('{"error":{"message":"account 1234 is out of credit"}}', { status: upstreamStatus }),
    );
    try {
      const response = await worker.fetch(explainRequest(signTransaction(activePayload())), baseEnv());
      assert.equal(response.status, expectedStatus);
      assert.deepEqual(await response.json(), { error: expectedCode });
    } finally {
      upstream.restore();
    }
  }
});

test('an empty model reply is an error, not an empty explanation', async () => {
  const upstream = stubUpstream(() => upstreamReply('   '));
  try {
    const response = await worker.fetch(explainRequest(signTransaction(activePayload())), baseEnv());
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'empty_reply' });
  } finally {
    upstream.restore();
  }
});

test('streaming replies pass through untouched', async () => {
  const chunks = 'data: {"choices":[{"delta":{"content":"血"}}]}\n\n';
  const upstream = stubUpstream(
    () =>
      new Response(chunks, { status: 200, headers: { 'content-type': 'text/event-stream' } }),
  );
  try {
    const response = await worker.fetch(
      explainRequest(signTransaction(activePayload()), {
        system: 'short',
        user: 'Hb 112',
        stream: true,
      }),
      baseEnv(),
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'text/event-stream');
    assert.equal(await response.text(), chunks);
    assert.equal(upstream.calls[0].body.stream, true);
  } finally {
    upstream.restore();
  }
});

test('an unconfigured deployment says so instead of failing oddly', async () => {
  const response = await worker.fetch(
    explainRequest(signTransaction(activePayload())),
    baseEnv({ DEEPINFRA_MODEL: '' }),
  );
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: 'not_configured' });
});
