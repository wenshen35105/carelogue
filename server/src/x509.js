// X.509 certificate parsing and chain verification, built on WebCrypto.
// Only what Apple's StoreKit JWS chain needs: ECDSA certificates (P-256 leaf,
// P-384 root) signed with SHA-256 / SHA-384.

import {
  readElement,
  readChildren,
  oidToString,
  parseTime,
  bytesEqual,
  toHex,
} from './asn1.js';

const OID = {
  ecdsaWithSHA256: '1.2.840.10045.4.3.2',
  ecdsaWithSHA384: '1.2.840.10045.4.3.3',
  ecPublicKey: '1.2.840.10045.2.1',
  prime256v1: '1.2.840.10045.3.1.7',
  secp384r1: '1.3.132.0.34',
};

const CURVE_BY_OID = {
  [OID.prime256v1]: { name: 'P-256', size: 32 },
  [OID.secp384r1]: { name: 'P-384', size: 48 },
};

const HASH_BY_SIGNATURE_OID = {
  [OID.ecdsaWithSHA256]: 'SHA-256',
  [OID.ecdsaWithSHA384]: 'SHA-384',
};

/**
 * @typedef {object} Certificate
 * @property {Uint8Array} der          full certificate
 * @property {Uint8Array} tbs          bytes the signature covers
 * @property {Uint8Array} issuer       raw issuer Name
 * @property {Uint8Array} subject      raw subject Name
 * @property {Uint8Array} spki         SubjectPublicKeyInfo, ready for importKey
 * @property {string} signatureOid
 * @property {Uint8Array} signature    DER-encoded ECDSA signature
 * @property {number} notBefore
 * @property {number} notAfter
 * @property {{name: string, size: number}} curve
 */

/**
 * Parses a DER certificate.
 * @param {Uint8Array} der
 * @returns {Certificate}
 */
export function parseCertificate(der) {
  const certificate = readElement(der);
  const [tbsElement, signatureAlgorithm, signatureValue] = readChildren(certificate);

  const tbsChildren = readChildren(tbsElement);
  // [0] EXPLICIT version is optional; when present it is the first child.
  let index = tbsChildren[0].tag === 0xa0 ? 1 : 0;
  index += 1; // serialNumber
  index += 1; // inner signature AlgorithmIdentifier
  const issuer = tbsChildren[index++];
  const validity = tbsChildren[index++];
  const subject = tbsChildren[index++];
  const spki = tbsChildren[index++];

  const [notBefore, notAfter] = readChildren(validity);
  // SubjectPublicKeyInfo ::= SEQUENCE { algorithm AlgorithmIdentifier, subjectPublicKey BIT STRING }
  const [algorithm, parameters] = readChildren(readChildren(spki)[0]);

  if (oidToString(algorithm.bytes) !== OID.ecPublicKey) {
    throw new Error('x509: only EC public keys are supported');
  }
  const curve = CURVE_BY_OID[oidToString(parameters.bytes)];
  if (!curve) throw new Error('x509: unsupported curve');

  // BIT STRING content starts with the count of unused bits.
  const signature = signatureValue.bytes.subarray(1);

  return {
    der,
    tbs: tbsElement.raw,
    issuer: issuer.raw,
    subject: subject.raw,
    spki: spki.raw,
    signatureOid: oidToString(readChildren(signatureAlgorithm)[0].bytes),
    signature,
    notBefore: parseTime(notBefore),
    notAfter: parseTime(notAfter),
    curve,
  };
}

/**
 * ECDSA signatures travel DER-encoded inside certificates but WebCrypto wants
 * the raw r‖s pair.
 * @param {Uint8Array} der
 * @param {number} size bytes per coordinate
 */
export function derSignatureToRaw(der, size) {
  const sequence = readElement(der);
  const [r, s] = readChildren(sequence);
  const raw = new Uint8Array(size * 2);
  for (const [index, integer] of [r, s].entries()) {
    // DER integers are signed: drop a leading zero, left-pad short values.
    let bytes = integer.bytes;
    while (bytes.length > size && bytes[0] === 0) bytes = bytes.subarray(1);
    if (bytes.length > size) throw new Error('x509: signature integer too long');
    raw.set(bytes, index * size + (size - bytes.length));
  }
  return raw;
}

/**
 * Verifies `certificate` was signed by `issuer`.
 * @param {Certificate} certificate
 * @param {Certificate} issuer
 */
export async function verifySignedBy(certificate, issuer) {
  const hash = HASH_BY_SIGNATURE_OID[certificate.signatureOid];
  if (!hash) throw new Error('x509: unsupported signature algorithm');

  const key = await crypto.subtle.importKey(
    'spki',
    issuer.spki,
    { name: 'ECDSA', namedCurve: issuer.curve.name },
    false,
    ['verify'],
  );
  return crypto.subtle.verify(
    { name: 'ECDSA', hash },
    key,
    derSignatureToRaw(certificate.signature, issuer.curve.size),
    certificate.tbs,
  );
}

/**
 * SHA-256 of the DER certificate, lowercase hex — the value
 * `shasum -a 256 AppleRootCA-G3.cer` prints.
 * @param {Certificate} certificate
 */
export async function fingerprint(certificate) {
  return toHex(await crypto.subtle.digest('SHA-256', certificate.der));
}

/**
 * Validates a leaf→…→root chain: every link's signature, the issuer/subject
 * links, every certificate's validity window, and that the root is the one we
 * pinned (Apple Root CA G3).
 *
 * @param {Certificate[]} chain leaf first, root last
 * @param {string} rootFingerprint lowercase hex SHA-256 of the pinned root
 * @param {number} now epoch ms
 */
export async function verifyChain(chain, rootFingerprint, now = Date.now()) {
  if (chain.length < 2) throw new Error('x509: chain too short');

  for (const certificate of chain) {
    if (now < certificate.notBefore || now > certificate.notAfter) {
      throw new Error('x509: certificate outside its validity window');
    }
  }

  for (let i = 0; i < chain.length - 1; i++) {
    const certificate = chain[i];
    const issuer = chain[i + 1];
    if (!bytesEqual(certificate.issuer, issuer.subject)) {
      throw new Error('x509: broken issuer chain');
    }
    if (!(await verifySignedBy(certificate, issuer))) {
      throw new Error('x509: bad signature in chain');
    }
  }

  const root = chain[chain.length - 1];
  if ((await fingerprint(root)) !== rootFingerprint.toLowerCase()) {
    throw new Error('x509: root is not the pinned Apple root certificate');
  }
  if (!(await verifySignedBy(root, root))) {
    throw new Error('x509: root is not self-signed');
  }
  return true;
}
