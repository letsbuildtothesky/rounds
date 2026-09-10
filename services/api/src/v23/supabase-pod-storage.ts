import { createHash } from 'node:crypto';
import type { PodObjectStore, PodUpload } from './pod-assets.js';
import { podHash } from './pod-byte-verification.js';
import { podMaxBytes } from './pickup-validation.js';
import { pickupHttpError } from './pickup-http.js';
import { CommandRejection, TransactionUnavailable } from './transaction-runner.js';
import { podKey, podUploadCapabilities, podUploadPath, validPodUpload } from './pod-upload-capability.js';

export type SupabasePodConfig = Readonly<{
  storageOrigin: string; serviceKey: string; stagingBucket: string; verifiedBucket: string;
  uploadOrigin: string; signingKeyId: string; signingKey: Buffer;
}>;
const unavailable = (): never => { throw new TransactionUnavailable('PROVIDER_UNAVAILABLE'); };
function httpsOrigin(text: string): string {
  let url: URL;
  try { url = new URL(text); } catch { throw new Error('Explicit HTTPS POD origin required'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Explicit HTTPS POD origin required');
  }
  return url.origin;
}

async function readBounded(response: Response | Request, limit: number, signal: AbortSignal): Promise<Buffer> {
  const length = response.headers.get('content-length');
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > limit)) {
    void response.body?.cancel().catch(() => {}); return unavailable();
  }
  const reader = response.body?.getReader();
  if (!reader) return unavailable();
  const chunks: Buffer[] = []; let size = 0;
  const abort = () => { void reader.cancel().catch(() => {}); };
  signal.addEventListener('abort', abort, { once: true });
  try {
    for (;;) {
      signal.throwIfAborted();
      const { value, done } = await reader.read();
      signal.throwIfAborted();
      if (done) break;
      size += value.byteLength;
      if (size > limit) return unavailable();
      chunks.push(Buffer.from(value));
    }
    if (length !== null && Number(length) !== size) return unavailable();
    return Buffer.concat(chunks);
  } finally {
    signal.removeEventListener('abort', abort);
    void reader.cancel().catch(() => {}); reader.releaseLock();
  }
}

/** Supabase REST protocol adapter. Does not create buckets/policies, return a
 * provider credential, use an admin DB connection, or enable legacy uploads.
 * HTTPS fetch and private create-only buckets are explicit deployment inputs. */
export function createSupabasePodStorage(input: SupabasePodConfig, fetcher: typeof fetch = fetch, clock = () => Math.floor(Date.now() / 1000)) {
  const storageOrigin = httpsOrigin(input.storageOrigin), uploadOrigin = httpsOrigin(input.uploadOrigin);
  const staging = input.stagingBucket, verified = input.verifiedBucket, serviceKey = input.serviceKey;
  if (![staging, verified].every(x => /^[a-z][a-z0-9-]{2,62}$/.test(x)) || staging === verified ||
      !serviceKey || serviceKey.length < 20 || /\s/.test(serviceKey) || serviceKey.startsWith('sb_publishable_')) {
    throw new Error('Dedicated private POD buckets and server credential required');
  }
  const audience = createHash('sha256').update(JSON.stringify([storageOrigin, uploadOrigin, staging, verified])).digest('hex');
  const capabilities = podUploadCapabilities({ id: input.signingKeyId, secret: input.signingKey }, audience);
  const bounded = (signal: AbortSignal) => AbortSignal.any([signal, AbortSignal.timeout(15000)]);
  function destination(key: string): { bucket: string; path: string } {
    if (typeof key !== 'string' || !podKey.test(key)) throw new CommandRejection('NOT_AUTHORIZED');
    const bucket = key.startsWith('pod-staging/') ? staging : verified;
    return { bucket, path: `/object/${bucket}/${key}` };
  }
  async function request(path: string, init: RequestInit, signal: AbortSignal): Promise<Response> {
    signal.throwIfAborted();
    try {
      // Path is generated only from fixed routes, validated bucket IDs and UUID keys.
      const response = await fetcher(`${storageOrigin}/storage/v1${path}`, { ...init,
        headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, ...init.headers },
        signal, redirect: 'error', cache: 'no-store' });
      if (response.redirected || response.status >= 300 && response.status < 400) {
        void response.body?.cancel().catch(() => {}); return unavailable();
      }
      signal.throwIfAborted(); return response;
    } catch { return unavailable(); }
  }
  async function bucketIsPrivate(bucket: string, signal: AbortSignal): Promise<number> {
    const response = await request(`/bucket/${bucket}`, { method: 'GET' }, signal);
    if (response.status !== 200) { void response.body?.cancel().catch(() => {}); return unavailable(); }
    let data: Record<string, unknown>;
    try { data = JSON.parse((await readBounded(response, 8192, signal)).toString('utf8')) as Record<string, unknown>; }
    catch { return unavailable(); }
    if (!data || data.id !== bucket || data.public !== false || !Number.isSafeInteger(data.file_size_limit) ||
        Number(data.file_size_limit) < 1 || Number(data.file_size_limit) > podMaxBytes ||
        !Array.isArray(data.allowed_mime_types) || data.allowed_mime_types.length !== 2 ||
        !['image/png', 'image/jpeg'].every(m => (data.allowed_mime_types as unknown[]).includes(m))) return unavailable();
    return Number(data.file_size_limit);
  }
  async function read(key: string, parent: AbortSignal): Promise<AsyncIterable<Uint8Array>> {
    const { bucket, path } = destination(key), signal = bounded(parent);
    await bucketIsPrivate(bucket, signal);
    const response = await request(path, { method: 'GET' }, signal);
    if (response.status !== 200) { void response.body?.cancel().catch(() => {}); return unavailable(); }
    // Enforce download bounds even when the server omits or lies about its size.
    const bytes = await readBounded(response, podMaxBytes, signal);
    return (async function* () { try { signal.throwIfAborted(); yield bytes; } finally { bytes.fill(0); } })();
  }
  async function createOnly(key: string, bytes: Buffer, mime: string, parent: AbortSignal): Promise<void> {
    const { bucket, path } = destination(key), signal = bounded(parent);
    if (!bytes.length || bytes.length > podMaxBytes || !['image/png', 'image/jpeg'].includes(mime)) return unavailable();
    if (await bucketIsPrivate(bucket, signal) < bytes.length) return unavailable();
    const response = await request(path, { method: 'POST', headers: {
      'content-type': mime, 'content-length': String(bytes.length), 'cache-control': 'max-age=0', 'x-upsert': 'false',
    }, body: new Uint8Array(bytes) }, signal);
    // Never use PUT/update/upsert/delete to "repair" conflicts or uncertain IO.
    // Existing object is acceptable only if its actual bytes are identical.
    if (![200, 201, 400, 409].includes(response.status)) {
      void response.body?.cancel().catch(() => {}); return unavailable();
    }
    const status = response.status;
    const detail = await readBounded(response, 8192, signal);
    if (status === 400 || status === 409) {
      let error: { code?: unknown; error?: unknown };
      try { error = JSON.parse(detail.toString('utf8')) as typeof error; } catch { return unavailable(); }
      if (!error || !['ResourceAlreadyExists', 'KeyAlreadyExists'].includes(String(error.code)) && error.error !== 'Duplicate') return unavailable();
    }
    const stream = await read(key, signal);
    const parts: Buffer[] = [];
    for await (const part of stream) parts.push(Buffer.from(part));
    const saved = Buffer.concat(parts);
    try { if (saved.length !== bytes.length || podHash(saved) !== podHash(bytes)) return unavailable(); }
    finally { saved.fill(0); for (const part of parts) part.fill(0); }
  }
  const store: PodObjectStore = {
    async issueUpload(upload: PodUpload, parent: AbortSignal) {
      const frozen = { ...upload }, signal = bounded(parent);
      if (!validPodUpload(frozen)) throw new CommandRejection('NOT_AUTHORIZED');
      if (await bucketIsPrivate(staging, signal) < frozen.byteSize || await bucketIsPrivate(verified, signal) < frozen.byteSize) return unavailable();
      signal.throwIfAborted();
      const cap = capabilities.issue(frozen, clock());
      return { upload_url: `${uploadOrigin}${podUploadPath}?cap=${cap.token}`, upload_token: null,
        upload_method: 'PUT', expires_at: cap.expiresAt };
    },
    read,
    async seal(key, bytes, mime, signal) {
      if (!key.startsWith('pod-verified/')) throw new CommandRejection('NOT_AUTHORIZED');
      const copy=Buffer.from(bytes);
      try {await createOnly(key, copy, mime, signal);} finally {copy.fill(0);}
    },
  };
  let active = 0;
  async function upload(request: Request): Promise<Response> {
    let bytes: Buffer | undefined;
    if (active >= 2) return pickupHttpError('RATE_LIMITED');
    active++;
    try {
      const url = new URL(request.url), params = url.searchParams;
      if (url.pathname !== podUploadPath || request.method !== 'PUT' || url.hash ||
          [...params.keys()].some(k => k !== 'cap') || params.getAll('cap').length !== 1 ||
          ['authorization', 'cookie', 'x-rounds-device-session', 'content-encoding', 'origin'].some(h => request.headers.has(h))) {
        throw new CommandRejection('NOT_AUTHORIZED');
      }
      const token = params.get('cap')!, cap = capabilities.verify(token, clock());
      if (request.headers.get('content-type') !== cap.mimeType ||
          request.headers.has('content-length') && request.headers.get('content-length') !== String(cap.byteSize)) {
        throw new CommandRejection('VALIDATION_FAILED');
      }
      const signal = AbortSignal.any([request.signal, AbortSignal.timeout(30000)]);
      bytes = await readBounded(request, cap.byteSize, signal);
      if (bytes.length !== cap.byteSize || podHash(bytes) !== cap.sha256) throw new CommandRejection('VALIDATION_FAILED');
      capabilities.verify(token, clock()); // Expiry checked again after body IO.
      await createOnly(cap.key, bytes, cap.mimeType, signal);
      return new Response(null, { status: 204, headers: { 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' } });
    } catch (error) {
      return pickupHttpError(error instanceof CommandRejection ? error.code : 'PROVIDER_UNAVAILABLE');
    } finally { bytes?.fill(0); active--; }
  }
  return { store, upload };
}

/** Inert unless explicitly opted in. No legacy/shared credential fallback. */
export function configuredPodStorage(env: NodeJS.ProcessEnv) {
  if (!env.ROUNDS_V23_POD_MODE || env.ROUNDS_V23_POD_MODE === 'disabled') return undefined;
  if (env.ROUNDS_V23_POD_MODE !== 'supabase' || env.APP_ENV !== 'local' || env.ROUNDS_V23_HTTP_MODE !== 'isolated') {
    throw new Error('POD provider is gated to isolated local development');
  }
  const key = env.ROUNDS_V23_POD_SIGNING_KEY ?? '', retentionClass = env.ROUNDS_V23_POD_RETENTION_CLASS ?? '';
  if (!/^[a-f0-9]{64}$/.test(key) || key.toLowerCase() === env.ROUNDS_V23_DEVICE_SESSION_KEY?.toLowerCase() ||
      !/^[a-z][a-z0-9_-]{1,63}$/.test(retentionClass)) throw new Error('Dedicated POD signing key and retention class required');
  const provider = createSupabasePodStorage({ storageOrigin: env.ROUNDS_V23_POD_STORAGE_ORIGIN ?? '',
    serviceKey: env.ROUNDS_V23_POD_SERVICE_KEY ?? '', stagingBucket: env.ROUNDS_V23_POD_STAGING_BUCKET ?? '',
    verifiedBucket: env.ROUNDS_V23_POD_VERIFIED_BUCKET ?? '', uploadOrigin: env.ROUNDS_V23_POD_UPLOAD_ORIGIN ?? '',
    signingKeyId: env.ROUNDS_V23_POD_SIGNING_KEY_ID ?? '', signingKey: Buffer.from(key, 'hex') });
  return { ...provider, retentionClass };
}
