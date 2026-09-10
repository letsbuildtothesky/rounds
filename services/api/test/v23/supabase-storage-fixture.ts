import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import type { SupabasePodConfig } from '../../src/v23/supabase-pod-storage.js';
import { podMaxBytes } from '../../src/v23/pickup-validation.js';

/** Explicit Supabase REST double. Never contacts a Supabase account. */
export function supabaseStorageFixture() {
  const config: SupabasePodConfig = { storageOrigin: 'https://storage.example', uploadOrigin: 'https://uploads.example',
    serviceKey: 'fixture-only-storage-service-key-not-a-credential', stagingBucket: 'test-pod-staging', verifiedBucket: 'test-pod-verified',
    signingKeyId: 'test-pod', signingKey: randomBytes(32) };
  const objects = new Map<string, Buffer>(), calls: { method: string; path: string }[] = [];
  const buckets = new Map([config.stagingBucket, config.verifiedBucket].map(id => [id, {
    id, public: false, file_size_limit: podMaxBytes, allowed_mime_types: ['image/png', 'image/jpeg'],
  }]));
  let intercept: ((path: string, init: RequestInit) => Promise<Response | undefined>) | undefined;
  const fetcher: typeof fetch = async (input, init = {}) => {
    const url = new URL(String(input)), method = init.method ?? 'GET';
    assert.equal(url.origin, config.storageOrigin);
    assert.equal(url.search, '');
    assert.equal(init.redirect, 'error'); assert.equal(init.cache, 'no-store');
    assert.ok(init.signal); init.signal.throwIfAborted();
    const headers = new Headers(init.headers);
    assert.equal(headers.get('apikey'), config.serviceKey);
    assert.equal(headers.get('authorization'), `Bearer ${config.serviceKey}`);
    assert.equal(headers.has('cookie'), false);
    calls.push({ method, path: url.pathname });
    const special = await intercept?.(url.pathname, init); if (special) return special;
    if (url.pathname.startsWith('/storage/v1/bucket/')) {
      assert.equal(method, 'GET');
      const data = buckets.get(url.pathname.slice('/storage/v1/bucket/'.length));
      return data ? Response.json(data) : Response.json({ code: 'NoSuchBucket' }, { status: 404 });
    }
    assert.ok(url.pathname.startsWith('/storage/v1/object/'));
    const key = url.pathname.slice('/storage/v1/object/'.length);
    if (method === 'POST') {
      assert.equal(headers.get('x-upsert'), 'false');
      if (objects.has(key)) return Response.json({ code: 'ResourceAlreadyExists' }, { status: 400 });
      const bytes = Buffer.from(init.body as Uint8Array);
      assert.equal(Number(headers.get('content-length')), bytes.length);
      objects.set(key, bytes);
      return Response.json({ Id: 'fixture-object-id', Key: key });
    }
    assert.equal(method, 'GET', 'no object update/delete/list or sign route');
    const bytes = objects.get(key);
    return bytes ? new Response(new Uint8Array(bytes), { headers: { 'content-length': String(bytes.length) } }) :
      Response.json({ code: 'NoSuchKey' }, { status: 404 });
  };
  return { config, objects, calls, buckets, fetcher, intercept: (fn: typeof intercept) => { intercept = fn; } };
}
