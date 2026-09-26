// Bundled entry point.
//
// Wrangler turns the Markdown files under docs/legal/ and docs/web/ into
// string modules (the Text rule in wrangler.toml), so the site's pages ship
// inside the Worker — there is no filesystem at the edge, and no second place
// to keep the text. Everything else lives in index.js, which stays importable
// by plain Node so the tests can run without a bundler.

import { createWorker } from './index.js';
import privacy from '../../docs/legal/privacy-policy.md';
import terms from '../../docs/legal/terms-of-service.md';
import support from '../../docs/web/support.md';

export default createWorker({ privacy, terms, support });
