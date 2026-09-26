// A small Markdown renderer — just the subset docs/legal/*.md and
// docs/web/support.md actually use: headings, paragraphs, bold, links, bullet
// and numbered lists, tables and rules.
//
// Hand-rolled for the same reason as the rest of this Worker: no dependencies
// to audit, and the input is our own text, not user content. Everything is
// escaped anyway.

/** Escapes the five characters that could otherwise become markup. */
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** A link's target may only be one of these — anything else stays plain text. */
const LINK_SCHEMES = /^(https?:|mailto:)/i;

/** Inline formatting, applied to already-escaped text. */
function inline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (whole, label, href) =>
      LINK_SCHEMES.test(href) ? `<a href="${href}">${label}</a>` : whole);
}

const CJK = /[　-〿㐀-䶿一-鿿＀-￯]/;

/**
 * Joins hard-wrapped lines back into one. A space belongs between two Latin
 * words, but not between two CJK characters — the source wraps mid-sentence,
 * and a naive join would sprinkle spaces through the Chinese text.
 */
export function joinWrapped(lines) {
  return lines.reduce((joined, line) => {
    const next = line.trim();
    if (!joined) return next;
    const left = joined[joined.length - 1];
    const right = next[0];
    const glue = CJK.test(left) && CJK.test(right) ? '' : ' ';
    return joined + glue + next;
  }, '');
}

const HEADING = /^(#{1,6})\s+(.*)$/;
const RULE = /^(-{3,}|\*{3,})\s*$/;
const BULLET = /^\s*[-*]\s+(.*)$/;
const NUMBERED = /^\s*\d+\.\s+(.*)$/;

function startsBlock(line) {
  return !line.trim() || HEADING.test(line) || RULE.test(line)
    || BULLET.test(line) || NUMBERED.test(line) || line.trimStart().startsWith('|');
}

/** Splits a table row into cells, dropping the leading/trailing pipes. */
function cellsOf(line) {
  return line.trim().replace(/^\||\|$/g, '').split('|').map((cell) => cell.trim());
}

function isTableSeparator(line = '') {
  return /^\s*\|?[\s:-]*-[\s|:-]*\|?\s*$/.test(line) && line.includes('-');
}

function readTable(lines, start) {
  const header = cellsOf(lines[start]);
  let index = start + 2; // header + separator
  const rows = [];
  while (index < lines.length && lines[index].trim().startsWith('|')) {
    rows.push(cellsOf(lines[index]));
    index += 1;
  }
  const head = `<thead><tr>${header.map((cell) => `<th>${inline(cell)}</th>`).join('')}</tr></thead>`;
  const body = rows
    .map((row) => `<tr>${row.map((cell) => `<td>${inline(cell)}</td>`).join('')}</tr>`)
    .join('');
  return [`<table>${head}<tbody>${body}</tbody></table>`, index];
}

function readList(lines, start) {
  const ordered = NUMBERED.test(lines[start]);
  const items = [];
  let index = start;

  while (index < lines.length) {
    const line = lines[index];
    const match = ordered ? NUMBERED.exec(line) : BULLET.exec(line);
    if (match) {
      items.push([match[1]]);
      index += 1;
      continue;
    }
    // An indented continuation belongs to the item above it.
    if (items.length && line.trim() && /^\s+/.test(line)) {
      items[items.length - 1].push(line);
      index += 1;
      continue;
    }
    break;
  }

  const tag = ordered ? 'ol' : 'ul';
  const body = items.map((item) => `<li>${inline(joinWrapped(item))}</li>`).join('');
  return [`<${tag}>${body}</${tag}>`, index];
}

function readParagraph(lines, start) {
  const collected = [lines[start]];
  let index = start + 1;
  while (index < lines.length && !startsBlock(lines[index])) {
    collected.push(lines[index]);
    index += 1;
  }
  return [joinWrapped(collected), index];
}

/**
 * Markdown -> HTML fragment.
 * @param {string} source
 * @returns {string}
 */
export function renderMarkdown(source) {
  const lines = source.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];

    if (!line.trim()) {
      index += 1;
      continue;
    }
    if (RULE.test(line)) {
      out.push('<hr>');
      index += 1;
      continue;
    }

    const heading = HEADING.exec(line);
    if (heading) {
      const level = heading[1].length;
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      index += 1;
      continue;
    }

    if (line.trimStart().startsWith('|') && isTableSeparator(lines[index + 1])) {
      const [table, next] = readTable(lines, index);
      out.push(table);
      index = next;
      continue;
    }

    if (BULLET.test(line) || NUMBERED.test(line)) {
      const [list, next] = readList(lines, index);
      out.push(list);
      index = next;
      continue;
    }

    const [paragraph, next] = readParagraph(lines, index);
    out.push(`<p>${inline(paragraph)}</p>`);
    index = next;
  }

  return out.join('\n');
}

/**
 * The document's `# Title`, for the page title and the header.
 * @param {string} source
 */
export function titleOf(source) {
  const match = /^#\s+(.*)$/m.exec(source);
  return match ? match[1].trim() : 'Carelogue';
}
