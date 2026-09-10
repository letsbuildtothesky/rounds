import { createHmac, timingSafeEqual } from 'node:crypto';
import type { PodUpload } from './pod-assets.js';
import { podMaxBytes } from './pickup-validation.js';
import { CommandRejection } from './transaction-runner.js';

export const podUploadPath = '/v1/media/pod-upload';
const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
export const podKey = new RegExp(`^(pod-staging|pod-verified)/${uuid}/${uuid}/${uuid}$`);
export function validPodUpload(value: PodUpload): boolean {
  return !!value && typeof value === 'object' && typeof value.key === 'string' &&
    podKey.test(value.key) && value.key.startsWith('pod-staging/') &&
    ['image/png', 'image/jpeg'].includes(value.mimeType) && Number.isSafeInteger(value.byteSize) &&
    value.byteSize > 0 && value.byteSize <= podMaxBytes && /^[a-f0-9]{64}$/.test(value.sha256);
}
type Claims = PodUpload & { purpose: 'rounds.pod-upload.v1'; kid: string; audience: string; iat: number; exp: number };
const fields = ['key', 'mimeType', 'byteSize', 'sha256', 'purpose', 'kid', 'audience', 'iat', 'exp'].sort().join(',');
const deny = (): never => { throw new CommandRejection('NOT_AUTHORIZED'); };

/** Internal signer only. A finite bearer grant for exact bytes, not login or a
 * business command. No keys/capabilities are written to receipts or logs. */
export function podUploadCapabilities(key: { id: string; secret: Buffer }, audience: string) {
  if (!/^[A-Za-z0-9_-]{1,32}$/.test(key.id) || key.secret.length !== 32 || !audience) {
    throw new Error('Dedicated POD upload signing configuration required');
  }
  const secret = Buffer.from(key.secret), kid = key.id;
  const mac = (text: string) => createHmac('sha256', secret).update(text).digest();
  function valid(c: Claims, now: number): boolean {
    return validPodUpload(c) && Object.keys(c).sort().join(',') === fields &&
      c.purpose === 'rounds.pod-upload.v1' && c.kid === kid && c.audience === audience &&
      Number.isSafeInteger(now) && Number.isSafeInteger(c.iat) && Number.isSafeInteger(c.exp) &&
      c.iat >= 0 && c.iat <= now && c.exp > now && c.exp > c.iat && c.exp - c.iat <= 300;
  }
  return {
    issue(upload: PodUpload, now: number): { token: string; expiresAt: string } {
      const c: Claims = { ...upload, purpose: 'rounds.pod-upload.v1', kid, audience, iat: now, exp: now + 240 };
      if (!valid(c, now)) return deny();
      const payload = Buffer.from(JSON.stringify(c)).toString('base64url');
      return { token: `${payload}.${mac(payload).toString('base64url')}`, expiresAt: new Date(c.exp * 1000).toISOString() };
    },
    verify(token: string, now: number): Readonly<Claims> {
      if (token.length > 2048 || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{43}$/.test(token)) return deny();
      const [payload, signature] = token.split('.') as [string, string];
      const bytes = Buffer.from(signature, 'base64url');
      if (bytes.toString('base64url') !== signature || !timingSafeEqual(bytes, mac(payload))) return deny();
      let claims: Claims;
      try { claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as Claims; } catch { return deny(); }
      if (!valid(claims, now)) return deny();
      return Object.freeze(claims);
    },
  };
}
