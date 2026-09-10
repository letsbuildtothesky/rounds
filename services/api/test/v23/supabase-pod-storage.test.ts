import assert from 'node:assert/strict';
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { createSupabasePodStorage, configuredPodStorage } from '../../src/v23/supabase-pod-storage.js';
import { podUploadCapabilities, podUploadPath } from '../../src/v23/pod-upload-capability.js';
import { createV23NodeBoundary, isV23Path } from '../../src/v23/node-boundary.js';
import { createV23Runtime } from '../../src/v23/runtime.js';
import { podHash } from '../../src/v23/pod-byte-verification.js';
import { podMaxBytes } from '../../src/v23/pickup-validation.js';
import { supabaseStorageFixture } from './supabase-storage-fixture.js';
import { headerRejection } from './header-rejection-fixture.js';

const signal = () => new AbortController().signal;
const path = (kind = 'pod-staging') => `${kind}/${randomUUID()}/${randomUUID()}/${randomUUID()}`;
function setup() {
  const fixture = supabaseStorageFixture(); let now = Math.floor(Date.now() / 1000);
  const service = createSupabasePodStorage(fixture.config, fixture.fetcher, () => now);
  const bytes = Buffer.from('selected synthetic image bytes');
  const selected = { key: path(), mimeType: 'image/png', byteSize: bytes.length, sha256: podHash(bytes) };
  const put = (url: string, data = bytes, headers: Record<string, string> = {}) => service.upload(new Request(url, {
    method: 'PUT', headers: { 'content-type': selected.mimeType, ...headers }, body: new Uint8Array(data),
  }));
  return { ...fixture, service, bytes, selected, put, advance: (seconds: number) => { now += seconds; } };
}
async function read(service: ReturnType<typeof createSupabasePodStorage>, key: string) {
  const parts: Buffer[] = [];
  for await (const bytes of await service.store.read(key, signal())) parts.push(Buffer.from(bytes));
  return Buffer.concat(parts);
}
test('POD provider is disabled by default and does not borrow existing credentials', () => {
  assert.equal(configuredPodStorage({ SUPABASE_SECRET_KEY: 'legacy' }), undefined);
  assert.equal(createV23Runtime({ ROUNDS_V23_POD_MODE: 'supabase' }, 'http://localhost:3000'), undefined);
  assert.throws(() => configuredPodStorage({ ROUNDS_V23_POD_MODE: 'supabase', APP_ENV: 'production' }), /gated/);
  assert.throws(() => configuredPodStorage({ ROUNDS_V23_POD_MODE: 'supabase', APP_ENV: 'local', ROUNDS_V23_HTTP_MODE: 'isolated' }), /Dedicated/);
});
for (const change of [
  { storageOrigin: 'http://storage.example' }, { storageOrigin: 'https://secret@storage.example' },
  { uploadOrigin: 'https://uploads.example/path' }, { uploadOrigin: 'https://uploads.example/?cap=x' },
  { stagingBucket: '../other' }, { verifiedBucket: 'test-pod-staging' },
  { serviceKey: 'sb_publishable_not_server_secret' }, { signingKey: randomBytes(16) },
]) test(`POD configuration rejects ${Object.keys(change)[0]}=${typeof Object.values(change)[0]}`, () => {
  const s = setup(); assert.throws(() => createSupabasePodStorage({ ...s.config, ...change }, s.fetcher)); assert.equal(s.calls.length, 0);
});
test('actual REST adapter keeps capabilities private, writes once and seals different server-only keys', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  assert.equal(cap.upload_token, null); assert.equal(cap.upload_method, 'PUT');
  assert.ok(Date.parse(cap.expires_at) - Date.now() <= 240000);
  assert.equal(new URL(cap.upload_url).pathname, podUploadPath);
  assert.ok(!JSON.stringify(cap).includes(s.config.serviceKey));
  assert.equal((await s.put(cap.upload_url)).status, 204);
  assert.equal((await s.put(cap.upload_url)).status, 204, 'same bytes retry cannot overwrite');
  assert.deepEqual(await read(s.service, s.selected.key), s.bytes);
  const sealed = path('pod-verified');
  await s.service.store.seal(sealed, s.bytes, 'image/png', signal());
  assert.deepEqual(await read(s.service, sealed), s.bytes);
  await assert.rejects(s.service.store.issueUpload({ ...s.selected, key: sealed }, signal()));
  await assert.rejects(s.service.store.seal(s.selected.key, s.bytes, 'image/png', signal()));
  assert.equal(s.objects.size, 2);
  assert.ok(s.calls.every(c => ['GET', 'POST'].includes(c.method)));
});
test('new capability after expiry keeps original key and exact bytes, old capability is denied', async () => {
  const s = setup(), old = await s.service.store.issueUpload(s.selected, signal());
  s.advance(240); assert.equal((await s.put(old.upload_url)).status, 403);
  const fresh = await s.service.store.issueUpload(s.selected, signal());
  assert.notEqual(fresh.upload_url, old.upload_url);
  assert.equal((await s.put(fresh.upload_url)).status, 204); assert.equal(s.objects.size, 1);
});
test('altered signature, another deployment audience, path and method cannot move a capability', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  const url = new URL(cap.upload_url), token = url.searchParams.get('cap')!;
  url.searchParams.set('cap', token.slice(0, -2) + (token.at(-2) === 'a' ? 'b' : 'a') + token.at(-1));
  assert.equal((await s.put(url.href)).status, 403);
  const other = createSupabasePodStorage({ ...s.config, stagingBucket: 'other-bucket' }, s.fetcher);
  assert.equal((await other.upload(new Request(cap.upload_url, { method: 'PUT', headers: { 'content-type': 'image/png' }, body: s.bytes }))).status, 403);
  assert.equal((await s.put(cap.upload_url.replace(podUploadPath, '/v1/other'))).status, 403);
  assert.equal((await s.service.upload(new Request(cap.upload_url))).status, 403);
  assert.equal((await s.put(cap.upload_url + '&cap=duplicate')).status, 403);
  assert.equal(s.objects.size, 0);
});
for (const headers of [{ authorization: 'Bearer user' }, { cookie: 'session=user' }, { 'x-rounds-device-session': 'device' },
  { origin: 'https://example.com' }, { 'content-encoding': 'gzip' }, { 'content-type': 'text/plain' }, { 'content-length': '1' }]) {
  test(`POD rejects unexpected ${Object.keys(headers)[0]} without forwarding credentials or bytes`, async () => {
    const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal()); s.calls.length = 0;
    assert.ok((await s.put(cap.upload_url, s.bytes, headers)).status >= 400);
    assert.equal(s.calls.length, 0); assert.equal(s.objects.size, 0);
  });
}
test('wrong body hash/length cannot be uploaded and corrupt existing object is never repaired', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  assert.equal((await s.put(cap.upload_url, Buffer.alloc(s.bytes.length))).status, 400);
  assert.equal((await s.put(cap.upload_url, s.bytes.subarray(1))).status, 400);
  const key = `${s.config.stagingBucket}/${s.selected.key}`;
  const bad = Buffer.alloc(s.bytes.length); s.objects.set(key, bad);
  assert.equal((await s.put(cap.upload_url)).status, 503); assert.deepEqual(s.objects.get(key), bad);
});
test('provider acknowledgement loss leaves real stored bytes available for verification', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  s.intercept(async (p, init) => {
    if (init.method !== 'POST') return undefined;
    s.objects.set(p.slice('/storage/v1/object/'.length), Buffer.from(init.body as Uint8Array));
    throw new Error('sensitive provider URL and credentials must never be echoed');
  });
  const response = await s.put(cap.upload_url);
  assert.equal(response.status, 503); assert.ok(!(await response.text()).includes('sensitive'));
  s.intercept(undefined);
  assert.deepEqual(await read(s.service, s.selected.key), s.bytes);
  assert.equal((await s.put(cap.upload_url)).status, 204); assert.equal(s.objects.size, 1);
});
for (const kind of ['staging-public', 'verified-public', 'missing', 'unbounded', 'too-small', 'wildcard', 'redirect']) {
  test(`POD refuses ${kind} provider configuration without giving out an upload capability`, async () => {
    const s = setup();
    if (kind === 'staging-public') s.buckets.get(s.config.stagingBucket)!.public = true;
    if (kind === 'verified-public') s.buckets.get(s.config.verifiedBucket)!.public = true;
    if (kind === 'missing') s.buckets.delete(s.config.stagingBucket);
    if (kind === 'unbounded') s.buckets.get(s.config.stagingBucket)!.file_size_limit = podMaxBytes + 1;
    if (kind === 'too-small') s.buckets.get(s.config.verifiedBucket)!.file_size_limit = 1;
    if (kind === 'wildcard') s.buckets.get(s.config.stagingBucket)!.allowed_mime_types = ['image/*'];
    if (kind === 'redirect') s.intercept(async () => new Response(null, { status: 302, headers: { location: 'https://evil.example' } }));
    await assert.rejects(s.service.store.issueUpload(s.selected, signal()), /PROVIDER_UNAVAILABLE/);
    assert.equal(s.objects.size, 0);
  });
}
test('privacy changed after issuing capability blocks the eventual upload', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  s.buckets.get(s.config.stagingBucket)!.public = true;
  assert.equal((await s.put(cap.upload_url)).status, 503); assert.equal(s.objects.size, 0);
});
test('aborted provider operation returns no capability and does not start network IO', async () => {
  const s = setup(), abort = new AbortController(); abort.abort();
  await assert.rejects(s.service.store.issueUpload(s.selected, abort.signal)); assert.equal(s.calls.length, 0);
});
test('oversized or never-ending provider response is bounded and aborts', async () => {
  const s = setup();
  s.intercept(async p => p.includes('/object/') ? new Response(new Uint8Array(podMaxBytes + 1)) : undefined);
  await assert.rejects(read(s.service, s.selected.key));
  let cancelled = false;
  s.intercept(async p => p.includes('/object/') ? new Response(new ReadableStream({ cancel() { cancelled = true; } })) : undefined);
  const abort = new AbortController();
  const result = s.service.store.read(s.selected.key, abort.signal);
  await new Promise(resolve => setTimeout(resolve, 10)); abort.abort();
  await assert.rejects(result); assert.equal(cancelled, true);
});
test('signed claims reject future, overlong, wrong purpose, unknown fields and sealed keys', () => {
  const s = setup(), key = { id: 'test', secret: randomBytes(32) }, audience = 'test-audience';
  const signer = podUploadCapabilities(key, audience), now = 1000;
  const original = signer.issue(s.selected, now).token;
  const c = JSON.parse(Buffer.from(original.split('.')[0]!, 'base64url').toString());
  for (const change of [{ iat: now + 1 }, { exp: now + 301 }, { purpose: 'login' }, { extra: true }, { key: path('pod-verified') }, { sha256: 'A'.repeat(64) }]) {
    const payload = Buffer.from(JSON.stringify({ ...c, ...change })).toString('base64url');
    const token = `${payload}.${createHmac('sha256', key.secret).update(payload).digest('base64url')}`;
    assert.throws(() => signer.verify(token, now));
  }
});
test('two in-flight uploads bound memory; third is rate-limited and identical concurrent writes remain one object', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  const controllers: ReadableStreamDefaultController<Uint8Array>[] = [];
  const held = () => s.service.upload(new Request(cap.upload_url, { method: 'PUT', headers: { 'content-type': 'image/png' },
    body: new ReadableStream<Uint8Array>({ start(c) { controllers.push(c); } }), duplex: 'half' } as RequestInit));
  const first = held(), second = held();
  assert.equal((await s.put(cap.upload_url)).status, 429);
  for (const c of controllers) { c.enqueue(new Uint8Array(s.bytes)); c.close(); }
  assert.deepEqual((await Promise.all([first, second])).map(r => r.status), [204, 204]); assert.equal(s.objects.size, 1);
});
test('capability expiring during body receipt cannot start a provider write', async () => {
  const s = setup(), cap = await s.service.store.issueUpload(s.selected, signal());
  let release!: () => void;
  const response = s.service.upload(new Request(cap.upload_url, { method: 'PUT', headers: { 'content-type': 'image/png' },
    body: new ReadableStream<Uint8Array>({ start(c) { release = () => { c.enqueue(new Uint8Array(s.bytes)); c.close(); }; } }), duplex: 'half' } as RequestInit));
  s.advance(240); release(); assert.equal((await response).status, 403); assert.equal(s.objects.size, 0);
});
test('explicit isolated provider settings construct without network IO and refuse reuse of device signing secret', () => {
  const s = setup();
  const env = { ROUNDS_V23_POD_MODE: 'supabase', APP_ENV: 'local', ROUNDS_V23_HTTP_MODE: 'isolated',
    ROUNDS_V23_POD_STORAGE_ORIGIN: s.config.storageOrigin, ROUNDS_V23_POD_UPLOAD_ORIGIN: s.config.uploadOrigin,
    ROUNDS_V23_POD_SERVICE_KEY: s.config.serviceKey, ROUNDS_V23_POD_STAGING_BUCKET: s.config.stagingBucket,
    ROUNDS_V23_POD_VERIFIED_BUCKET: s.config.verifiedBucket, ROUNDS_V23_POD_SIGNING_KEY_ID: s.config.signingKeyId,
    ROUNDS_V23_POD_SIGNING_KEY: s.config.signingKey.toString('hex'), ROUNDS_V23_POD_RETENTION_CLASS: 'synthetic-test-pod' };
  assert.ok(configuredPodStorage(env));
  assert.throws(() => configuredPodStorage({ ...env, ROUNDS_V23_DEVICE_SESSION_KEY: env.ROUNDS_V23_POD_SIGNING_KEY }), /Dedicated/);
});
test('Node upload boundary carries >1MiB raw bytes, denies browser/credential requests and stays default-off', async t => {
  const s = setup(); const bytes = Buffer.alloc(1024 * 1024 + 1, 8);
  const cap = await s.service.store.issueUpload({ ...s.selected, byteSize: bytes.length, sha256: podHash(bytes) }, signal());
  let enabled = true;
  const boundary = createV23NodeBoundary({ handler: r => s.service.upload(r), origin: 'http://localhost:3000' });
  const disabled = createV23NodeBoundary({ origin: 'http://localhost:3000' });
  const server = createServer((req, res) => { void (enabled ? boundary : disabled)(req, res); });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise<void>(resolve => { server.closeAllConnections(); server.close(() => resolve()); }));
  const address = server.address() as { port: number }, url = `http://127.0.0.1:${address.port}${podUploadPath}${new URL(cap.upload_url).search}`;
  assert.equal(isV23Path(podUploadPath), true, 'outer server logger must redact capability query');
  assert.equal((await fetch(url, { method: 'PUT', headers: { 'content-type': 'image/png' }, body: bytes })).status, 204);
  // Admission must reject headers without consuming the declared large body.
  // The accepted path above still transfers the actual >1MiB bytes.
  const headers = {'content-type': 'image/png', 'content-length': String(bytes.length)};
  assert.equal((await headerRejection(url, {method: 'PUT', headers: {...headers, authorization: 'Bearer wrong'}})).status, 403);
  enabled = false; assert.equal((await headerRejection(url, {method: 'PUT', headers})).status, 403);
});
