// The site's text pages (carelogue.ca/privacy, /terms and /support), rendered
// from the same Markdown the repo keeps under docs/legal/ and docs/web/ so the
// app, the App Store listing and the web copy can never drift apart.
//
// Styling follows the app's own palette (CLAUDE.md): warm rice-paper canvas,
// white cards, apricot accent, system fonts — with the Nocturne values under
// prefers-color-scheme: dark.

import { renderMarkdown, titleOf } from './markdown.js';

/** Which document each path serves. */
export const LEGAL_ROUTES = {
  '/privacy': 'privacy',
  '/terms': 'terms',
  '/support': 'support',
};

/** Masthead label for each page. */
const PAGES = {
  privacy: '隐私政策 · Privacy',
  terms: '使用条款 · Terms',
  support: '支持 · Support',
};

/** The pages each masthead links to, in order. */
const OTHERS = {
  privacy: ['terms', 'support'],
  terms: ['privacy', 'support'],
  support: ['privacy', 'terms'],
};

const STYLE = `
:root {
  color-scheme: light dark;
  --canvas: #F7F5F2;
  --card: #FFFFFF;
  --ink: #1C1B1A;
  --ink-soft: #8A8680;
  --border: #EAE6DF;
  --accent: #D9784F;
  --accent-tint: #FAF0EA;
}
@media (prefers-color-scheme: dark) {
  :root {
    --canvas: #17140F;
    --card: #221E1A;
    --ink: #F5F1EC;
    --ink-soft: #A39C93;
    --border: #332E28;
    --accent: #E08A63;
    --accent-tint: rgba(224, 138, 99, 0.15);
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 0 20px 64px;
  background: var(--canvas);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC",
    "Hiragino Sans GB", "Microsoft YaHei", Helvetica, Arial, sans-serif;
  font-size: 16px;
  line-height: 1.8;
  -webkit-text-size-adjust: 100%;
}
.wrap { max-width: 720px; margin: 0 auto; }
header.masthead {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  padding: 28px 0 20px;
}
.brand {
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
  text-decoration: none;
}
.masthead a.other {
  font-size: 14px;
  color: var(--ink-soft);
  text-decoration: none;
  border-bottom: 1px solid var(--border);
  padding-bottom: 2px;
}
.masthead a.other:hover { color: var(--accent); border-color: var(--accent); }
main {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 18px;
  padding: 28px 28px 36px;
  box-shadow: 0 4px 20px -2px rgba(28, 27, 26, 0.03), 0 2px 6px -1px rgba(28, 27, 26, 0.02);
}
@media (prefers-color-scheme: dark) { main { box-shadow: none; } }
h1 { font-size: 28px; line-height: 1.35; margin: 0 0 20px; letter-spacing: -0.01em; }
h2 {
  font-size: 20px;
  margin: 40px 0 12px;
  padding-top: 8px;
  letter-spacing: -0.005em;
}
h3 { font-size: 17px; margin: 28px 0 8px; }
p { margin: 0 0 14px; }
strong { font-weight: 600; }
code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.92em;
  background: var(--accent-tint);
  border-radius: 5px;
  padding: 1px 5px;
}
ul, ol { margin: 0 0 16px; padding-left: 22px; }
li { margin-bottom: 8px; }
hr { border: 0; border-top: 1px solid var(--border); margin: 36px 0; }
table {
  width: 100%;
  border-collapse: collapse;
  margin: 8px 0 20px;
  font-size: 15px;
  display: block;
  overflow-x: auto;
}
th, td {
  border: 1px solid var(--border);
  padding: 10px 12px;
  text-align: left;
  vertical-align: top;
}
th { background: var(--accent-tint); font-weight: 600; }
footer {
  margin-top: 28px;
  text-align: center;
  font-size: 13px;
  color: var(--ink-soft);
}
footer a { color: var(--ink-soft); }
`.trim();

/**
 * One site page, ready to serve.
 *
 * @param {string} markdown  the document, as committed under docs/legal/ or docs/web/
 * @param {keyof typeof OTHERS} document  which page this is
 * @returns {string} a complete HTML document
 */
export function renderLegalPage(markdown, document) {
  const title = titleOf(markdown);
  const body = renderMarkdown(markdown);
  const others = OTHERS[document].map((page) =>
    `<a class="other" href="/${page}">${PAGES[page]} →</a>`).join('');

  return `<!DOCTYPE html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Carelogue</title>
<meta name="description" content="${title}">
<meta name="color-scheme" content="light dark">
<style>${STYLE}</style>
</head>
<body>
<div class="wrap">
<header class="masthead">
<a class="brand" href="/privacy">Carelogue</a>
${others}
</header>
<main>
${body}
</main>
<footer>温和记录，陪你走好每一步 · Gentle records, with you every step</footer>
</div>
</body>
</html>
`;
}

/**
 * @param {string} markdown
 * @param {keyof typeof NAV} document
 */
export function legalResponse(markdown, document) {
  return new Response(renderLegalPage(markdown, document), {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      // The text only changes on deploy; let Cloudflare and browsers hold it.
      'cache-control': 'public, max-age=3600',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'no-referrer',
    },
  });
}
