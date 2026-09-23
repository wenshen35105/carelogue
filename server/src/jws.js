// JWS (compact serialization) verification for App Store signed transactions.
// Apple signs each transaction with a leaf certificate whose chain is carried
// in the header's x5c field and roots in Apple Root CA G3.

import { base64ToBytes, base64UrlToBytes } from './asn1.js';
import { parseCertificate, verifyChain } from './x509.js';

const ALGORITHM_HASH = { ES256: 'SHA-256', ES384: 'SHA-384' };

/**
 * Splits a compact JWS without verifying anything.
 * @param {string} token
 */
export function decodeJws(token) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('jws: not a compact JWS');
  const [headerPart, payloadPart, signaturePart] = parts;
  const decoder = new TextDecoder();
  return {
    header: JSON.parse(decoder.decode(base64UrlToBytes(headerPart))),
    payload: JSON.parse(decoder.decode(base64UrlToBytes(payloadPart))),
    signature: base64UrlToBytes(signaturePart),
    signedData: new TextEncoder().encode(`${headerPart}.${payloadPart}`),
  };
}

/**
 * Verifies the certificate chain in the header, then the signature over the
 * header and payload. Returns the payload; throws on anything unexpected.
 *
 * @param {string} token
 * @param {string} rootFingerprint lowercase hex SHA-256 of Apple Root CA G3
 * @param {number} now epoch ms
 */
export async function verifyJws(token, rootFingerprint, now = Date.now()) {
  const { header, payload, signature, signedData } = decodeJws(token);

  const hash = ALGORITHM_HASH[header.alg];
  if (!hash) throw new Error('jws: unsupported algorithm');
  if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error('jws: missing certificate chain');
  }

  const chain = header.x5c.map((entry) => parseCertificate(base64ToBytes(entry)));
  await verifyChain(chain, rootFingerprint, now);

  const leaf = chain[0];
  const key = await crypto.subtle.importKey(
    'spki',
    leaf.spki,
    { name: 'ECDSA', namedCurve: leaf.curve.name },
    false,
    ['verify'],
  );
  // JOSE signatures are already raw r‖s, unlike the DER form inside a certificate.
  const valid = await crypto.subtle.verify({ name: 'ECDSA', hash }, key, signature, signedData);
  if (!valid) throw new Error('jws: bad signature');

  return payload;
}
