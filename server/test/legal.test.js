import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { renderMarkdown, joinWrapped, titleOf } from '../src/markdown.js';
import { renderLegalPage } from '../src/legal.js';
import { createWorker } from '../src/index.js';

const LEGAL = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'docs', 'legal');
const WEB = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'docs', 'web');
const privacy = readFileSync(join(LEGAL, 'privacy-policy.md'), 'utf8');
const terms = readFileSync(join(LEGAL, 'terms-of-service.md'), 'utf8');
const support = readFileSync(join(WEB, 'support.md'), 'utf8');

const worker = createWorker({ privacy, terms, support });
const get = (path, method = 'GET') =>
  worker.fetch(new Request(`https://carelogue.ca${path}`, { method }), {});

// --- Markdown

test('renders the blocks the policies use', () => {
  const html = renderMarkdown(
    ['# Title', '', '## Section', '', 'A **bold** claim.', '', '- one', '- two', '', '---'].join('\n'),
  );
  assert.match(html, /<h1>Title<\/h1>/);
  assert.match(html, /<h2>Section<\/h2>/);
  assert.match(html, /<p>A <strong>bold<\/strong> claim\.<\/p>/);
  assert.match(html, /<ul><li>one<\/li><li>two<\/li><\/ul>/);
  assert.match(html, /<hr>/);
});

test('renders numbered lists and their wrapped continuations', () => {
  const html = renderMarkdown(['1. first step', '2. second step', '   keeps going', ''].join('\n'));
  assert.match(html, /<ol><li>first step<\/li><li>second step keeps going<\/li><\/ol>/);
});

test('renders tables with a header row', () => {
  const html = renderMarkdown(
    ['| Data | Where |', '|---|---|', '| Records | Your device |'].join('\n'),
  );
  assert.match(html, /<table><thead><tr><th>Data<\/th><th>Where<\/th><\/tr><\/thead>/);
  assert.match(html, /<tbody><tr><td>Records<\/td><td>Your device<\/td><\/tr><\/tbody>/);
});

test('rejoins hard-wrapped lines without spacing out Chinese', () => {
  assert.equal(joinWrapped(['只有在你主动点击「白话解释」时，这份报告里的文字才会经', '加密通道发送一次。']),
    '只有在你主动点击「白话解释」时，这份报告里的文字才会经加密通道发送一次。');
  assert.equal(joinWrapped(['Only the text is sent, over an', 'encrypted connection.']),
    'Only the text is sent, over an encrypted connection.');
  // A Latin word wrapping onto a Chinese line still needs its space.
  assert.equal(joinWrapped(['同步到你自己的', 'iCloud 私有库']), '同步到你自己的 iCloud 私有库');
});

test('escapes markup instead of passing it through', () => {
  const html = renderMarkdown('A <script>alert(1)</script> line & more');
  assert.match(html, /&lt;script&gt;/);
  assert.ok(!html.includes('<script>'));
  assert.match(html, /&amp; more/);
});

test('renders links, and only for web and mail schemes', () => {
  const html = renderMarkdown([
    'Email [support@carelogue.ca](mailto:support@carelogue.ca) or see',
    '[the policy](https://carelogue.ca/privacy) and',
    '[bad](javascript:alert(1)).',
  ].join('\n'));
  assert.match(html, /<a href="mailto:support@carelogue\.ca">support@carelogue\.ca<\/a>/);
  assert.match(html, /<a href="https:\/\/carelogue\.ca\/privacy">the policy<\/a>/);
  assert.ok(!html.includes('<a href="javascript:'), 'only whitelisted schemes link');
  assert.match(html, /\[bad\]\(javascript:alert\(1\)\)/, 'the rest stays literal, escaped');
});

// --- Pages

test('the page carries the document, the palette and a link to the other one', () => {
  const html = renderLegalPage(privacy, 'privacy');
  assert.match(html, /<title>Carelogue 隐私政策 · Privacy Policy — Carelogue<\/title>/);
  assert.match(html, /<html lang="zh-Hans">/);
  assert.match(html, /#D9784F/, 'apricot accent');
  assert.match(html, /prefers-color-scheme: dark/);
  assert.match(html, /href="\/terms"/, 'links to the other document');
  assert.match(html, /我们不收集/);
  assert.match(html, /support@carelogue\.ca/);
});

test('titleOf reads the document heading', () => {
  assert.equal(titleOf(terms), 'Carelogue 使用条款 · Terms of Use');
});

test('the support page carries the FAQ, the contact and links to both policies', () => {
  const html = renderLegalPage(support, 'support');
  assert.match(html, /<title>Carelogue 支持 · Support — Carelogue<\/title>/);
  assert.match(html, /常见问题/);
  assert.match(html, /Frequently asked questions/);
  assert.match(html, /<a href="mailto:support@carelogue\.ca">/);
  assert.match(html, /href="\/privacy"/, 'links to privacy');
  assert.match(html, /href="\/terms"/, 'links to terms');
});

// --- Routes

test('serves every page as HTML', async () => {
  for (const [path, marker] of [['/privacy', '隐私'], ['/terms', '使用条款'], ['/support', '常见问题']]) {
    const response = await get(path);
    assert.equal(response.status, 200, path);
    assert.equal(response.headers.get('content-type'), 'text/html; charset=utf-8');
    assert.match(response.headers.get('cache-control'), /max-age=\d+/);
    assert.match(await response.text(), new RegExp(marker));
  }
});

test('a trailing slash is the same page', async () => {
  const response = await get('/privacy/');
  assert.equal(response.status, 200);
  assert.match(await response.text(), /隐私政策/);
});

test('HEAD answers without a body', async () => {
  const response = await get('/terms', 'HEAD');
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'text/html; charset=utf-8');
  assert.equal(await response.text(), '');
});

test('policy paths do not accept writes', async () => {
  const response = await get('/privacy', 'POST');
  assert.equal(response.status, 405);
});

test('unknown paths are still 404, and the API is untouched', async () => {
  assert.equal((await get('/privacy-policy')).status, 404);
  const health = await get('/v1/health');
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { ok: true });
});

test('a deployment without the documents says so instead of serving a blank page', async () => {
  const bare = createWorker({});
  const response = await bare.fetch(new Request('https://carelogue.ca/privacy'), {});
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: 'not_configured' });
});
