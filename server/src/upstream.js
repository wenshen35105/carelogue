// The one call this service makes: DeepInfra's OpenAI-compatible chat
// completions endpoint (spec §11).
//
// Nothing about a request or a reply is logged or stored. The prompt is built
// on the device, passed through here, and forgotten when the request ends.

const ENDPOINT = 'https://api.deepinfra.com/v1/openai/chat/completions';

export class UpstreamError extends Error {
  /**
   * @param {string} reason machine-readable reason the app maps to a message
   * @param {number} status status to return to the app
   */
  constructor(reason, status) {
    super(`upstream: ${reason}`);
    this.reason = reason;
    this.status = status;
  }
}

/**
 * @typedef {object} ExplainRequest
 * @property {string} system
 * @property {string} user
 * @property {boolean} [json]    ask the model for a single JSON object
 * @property {boolean} [stream]
 */

/**
 * @param {ExplainRequest} request
 * @param {{apiKey: string, model: string, timeoutMs?: number}} config
 * @returns {Promise<Response>} the upstream response, for the caller to pass through
 */
export async function complete(request, config) {
  const body = {
    model: config.model,
    messages: [
      { role: 'system', content: request.system },
      { role: 'user', content: request.user },
    ],
    temperature: 0.3,
    stream: request.stream === true,
  };
  if (request.json) body.response_format = { type: 'json_object' };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs ?? 60_000);

  let response;
  try {
    response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (error) {
    throw new UpstreamError(error.name === 'AbortError' ? 'timeout' : 'unreachable', 504);
  } finally {
    clearTimeout(timeout);
  }

  if (response.ok) return response;

  // Upstream failures are mapped, never forwarded verbatim: the reply body can
  // carry account details that are ours, not the user's business.
  switch (response.status) {
    case 401:
    case 403:
      throw new UpstreamError('provider_auth', 502);
    case 402:
      throw new UpstreamError('provider_balance', 502);
    case 429:
      throw new UpstreamError('provider_busy', 429);
    default:
      throw new UpstreamError('provider_error', 502);
  }
}

/**
 * Pulls the assistant's text out of a non-streaming reply.
 * @param {any} payload
 */
export function contentOf(payload) {
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new UpstreamError('empty_reply', 502);
  }
  return content;
}
