// Minimal DER reader — just enough of ASN.1 to walk an X.509 certificate.
// Hand-rolled on purpose: the Worker runs with no dependencies, so there is
// nothing to audit but this file.

/**
 * One DER element.
 * @typedef {{tag: number, header: number, length: number, start: number, end: number, bytes: Uint8Array, raw: Uint8Array}} Element
 * `bytes` is the content, `raw` is the full element including its header.
 */

/**
 * Reads the element starting at `offset`.
 * @param {Uint8Array} data
 * @param {number} offset
 * @returns {Element}
 */
export function readElement(data, offset = 0) {
  if (offset + 2 > data.length) throw new Error('DER: truncated element');
  const tag = data[offset];
  let cursor = offset + 1;
  let length = data[cursor++];

  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new Error('DER: unsupported length');
    length = 0;
    for (let i = 0; i < count; i++) length = (length << 8) | data[cursor++];
  }
  const start = cursor;
  const end = start + length;
  if (end > data.length) throw new Error('DER: length past end of buffer');

  return {
    tag,
    header: start - offset,
    length,
    start,
    end,
    bytes: data.subarray(start, end),
    raw: data.subarray(offset, end),
  };
}

/**
 * Reads every element inside a constructed element.
 * @param {Element} element
 * @returns {Element[]}
 */
export function readChildren(element) {
  const children = [];
  let offset = 0;
  while (offset < element.bytes.length) {
    const child = readElement(element.bytes, offset);
    children.push(child);
    offset += child.header + child.length;
  }
  return children;
}

/**
 * Dotted-decimal form of an OBJECT IDENTIFIER's content bytes.
 * @param {Uint8Array} bytes
 * @returns {string}
 */
export function oidToString(bytes) {
  if (bytes.length === 0) return '';
  const parts = [Math.floor(bytes[0] / 40), bytes[0] % 40];
  let value = 0;
  for (let i = 1; i < bytes.length; i++) {
    value = value * 128 + (bytes[i] & 0x7f);
    if (!(bytes[i] & 0x80)) {
      parts.push(value);
      value = 0;
    }
  }
  return parts.join('.');
}

/**
 * UTCTime / GeneralizedTime -> epoch milliseconds.
 * @param {Element} element
 * @returns {number}
 */
export function parseTime(element) {
  const text = new TextDecoder().decode(element.bytes);
  // UTCTime: YYMMDDHHMMSSZ (tag 0x17) · GeneralizedTime: YYYYMMDDHHMMSSZ (0x18)
  const isUTC = element.tag === 0x17;
  const year = isUTC
    ? 2000 + Number(text.slice(0, 2)) - (Number(text.slice(0, 2)) >= 50 ? 100 : 0)
    : Number(text.slice(0, 4));
  const rest = isUTC ? text.slice(2) : text.slice(4);
  const month = Number(rest.slice(0, 2));
  const day = Number(rest.slice(2, 4));
  const hour = Number(rest.slice(4, 6));
  const minute = Number(rest.slice(6, 8));
  const second = Number(rest.slice(8, 10) || '0');
  return Date.UTC(year, month - 1, day, hour, minute, second);
}

/**
 * True when two byte ranges are identical.
 * @param {Uint8Array} a
 * @param {Uint8Array} b
 */
export function bytesEqual(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

/**
 * Lowercase hex, the form `shasum -a 256` prints.
 * @param {ArrayBuffer | Uint8Array} buffer
 */
export function toHex(buffer) {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Decodes standard base64 (not base64url) into bytes.
 * @param {string} value
 */
export function base64ToBytes(value) {
  const binary = atob(value.replace(/\s+/g, ''));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Decodes base64url (JWS segments) into bytes.
 * @param {string} value
 */
export function base64UrlToBytes(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  return base64ToBytes(padded + '='.repeat((4 - (padded.length % 4)) % 4));
}
