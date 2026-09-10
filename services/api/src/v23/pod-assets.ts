import { randomUUID } from 'node:crypto';
import type { Pool, PoolClient } from 'pg';
import type { Wire_ReserveAssetRequest, Wire_ReserveAssetResult, Wire_VerifyAssetRequest, Wire_VerifyAssetResult, Wire_Event_asset_reserved, Wire_ResourceVersion } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { authorizeTeamPickupCity, authorizeTeamPickupJob } from './pickup-authorization.js';
import { canonicalCommandJson } from './command-identity.js';
import { beginRestrictedTransaction } from './restricted-transaction.js';
import { validateAssetEvent, validateAssetResult, validateReserveAssetRequest, validateVerifyAssetRequest } from './pickup-validation.js';
import { readPodBytes, podHash, verifyPodImage } from './pod-byte-verification.js';
import { pickupIssueAssetPurpose, loadBoundPickupIssueAsset, bindPickupIssueAsset, type PickupIssueAssetScope } from './pickup-issue-assets.js';
import { assertExpectedVersions, CommandRejection, CommandTransactionRunner, TransactionUnavailable, type CommandAuthority, type CommandResult, type CommandWork, type ReceiptJobScope } from './transaction-runner.js';
export const reserveAssetPath = '/v1/commands/ReserveAsset';
export const verifyAssetPath = '/v1/commands/VerifyAsset';
export type PodUpload = Readonly<{
    key: string;
    mimeType: string;
    byteSize: number;
    sha256: string;
}>;
/** Server-only provider seam. Staging capabilities are write-once, private,
 * key/type/size/hash-bound and <=300s. Sealed keys have NO client write grants.
 * An adapter must honor AbortSignal and acknowledge durable, immutable writes.
 * No provider is configured by default or borrowed from legacy credentials. */
export interface PodObjectStore {
    issueUpload(upload: PodUpload, signal: AbortSignal): Promise<Omit<Wire_ReserveAssetResult['data'], 'asset_id'>>;
    read(key: string, signal: AbortSignal): Promise<AsyncIterable<Uint8Array>>;
    seal(key: string, bytes: Buffer, mimeType: string, signal: AbortSignal): Promise<void>;
}
type Scope = ReceiptJobScope & {
    delivery_id: string;
    stop_id: string;
    attempt_id: string;
    handoff_id: string;
    policy_version_id: string;
    receiver_contact_id: string | null;
    assignment_version: string;
};
type Asset = Scope & {
    id: string;
    upload_key: string;
    object_key: string;
    kind: string;
    state: string;
    mime_type: string;
    byte_size: string;
    sha256: string;
    version: string;
};
type Authorize = CommandWork['authorize'];
function reject(code: ConstructorParameters<typeof CommandRejection>[0]): never { throw new CommandRejection(code); }
const snapshot = <T>(value: T): T => JSON.parse(canonicalCommandJson(value)) as T;
const root = (id: string, version: number): Wire_ResourceVersion & {
    aggregate_type: 'assets';
} => ({ aggregate_type: 'assets', id, version });
/** The handoff's committed receipt chooses the original assignment. A later
 * assignment to the same driver cannot authorize this asset by substitution. */
async function purpose(client: PoolClient, auth: CommandAuthority, handoffId: string, lock = false): Promise<Scope> {
    const found = (await client.query<Scope>(`SELECT y.id AS delivery_id,s.id AS stop_id,a.id AS attempt_id,h.id AS handoff_id,
    h.proof_policy_id AS policy_version_id,h.receiver_contact_id,x.version AS assignment_version,
    s.round_id AS "roundId",x.id AS "assignmentId"
    FROM rounds.handoffs h JOIN rounds.delivery_attempts a ON a.tenant_id=h.tenant_id AND a.id=h.attempt_id
    JOIN rounds.stops s ON s.tenant_id=a.tenant_id AND s.id=a.stop_id AND s.delivery_id=a.delivery_id AND s.fulfillment_unit_id=a.fulfillment_unit_id
    JOIN rounds.deliveries y ON y.tenant_id=a.tenant_id AND y.id=a.delivery_id
    JOIN rounds.command_receipts c ON c.tenant_id=h.tenant_id AND c.actor_id=h.actor_id AND c.command_type='RecordHandoff'
      AND c.state='committed' AND c.result#>>'{data,handoff_id}'=h.id::text AND c.authorization_round_id=s.round_id
    JOIN rounds.assignments x ON x.tenant_id=h.tenant_id AND x.id=c.authorization_assignment_id AND x.round_id=s.round_id AND x.driver_id=a.driver_id
    JOIN rounds.drivers d ON d.id=x.driver_id AND d.principal_id=h.actor_id
    JOIN rounds.rounds r ON r.tenant_id=s.tenant_id AND r.id=s.round_id
    WHERE h.tenant_id=$1 AND h.id=$2 AND h.actor_id=$3 AND y.city_id=$4
      AND h.state='recorded' AND a.state='handed_over' AND s.state='handed_over' AND y.outcome='open'
      AND x.state='acknowledged' AND r.state='active' AND r.fulfillment_kind='team'
      AND h.archived_at IS NULL AND a.archived_at IS NULL AND s.archived_at IS NULL AND y.archived_at IS NULL
      AND x.archived_at IS NULL AND d.archived_at IS NULL AND r.archived_at IS NULL`, [auth.tenantId, handoffId, auth.principalId, auth.cityId])).rows;
    if (found.length !== 1)
        reject('NOT_AUTHORIZED');
    const scope = found[0]!;
    if (lock) {
        // Permission locks already held. Match execution's delivery -> Round /
        // assignment -> stop/attempt -> handoff -> asset ordering; no provider IO.
        for (const [table, id] of [['deliveries', scope.delivery_id], ['rounds', scope.roundId], ['assignments', scope.assignmentId], ['stops', scope.stop_id], ['delivery_attempts', scope.attempt_id], ['handoffs', scope.handoff_id]])
            await client.query(`SELECT id FROM rounds.${table} WHERE tenant_id=$1 AND id=$2 FOR UPDATE`, [auth.tenantId, id]);
        const rechecked = await purpose(client, auth, handoffId);
        if (canonicalCommandJson(rechecked) !== canonicalCommandJson(scope))
            reject('NOT_AUTHORIZED');
    }
    await authorizeTeamPickupJob(client, auth, scope.roundId, scope.assignmentId);
    return scope;
}
export async function loadBoundPodAsset(client: PoolClient, auth: CommandAuthority, id: string, lock = false): Promise<Asset> {
    const binding = (await client.query<{
        handoff_id: string;
        assignment_id: string;
        assignment_version: string;
        upload_key: string;
        policy_version_id: string;
        receiver_contact_id: string | null;
        attempt_id: string;
        round_id: string;
    }>(`SELECT handoff_id,assignment_id,assignment_version,upload_key,policy_version_id,receiver_contact_id,attempt_id,round_id FROM rounds.pod_asset_bindings WHERE tenant_id=$1 AND asset_id=$2 AND actor_id=$3 AND city_id=$4`, [auth.tenantId, id, auth.principalId, auth.cityId])).rows[0];
    if (!binding)
        reject('NOT_AUTHORIZED');
    const scope = await purpose(client, auth, binding.handoff_id, lock);
    if (scope.assignmentId !== binding.assignment_id || scope.assignment_version !== binding.assignment_version)
        reject('NOT_AUTHORIZED');
    if (scope.attempt_id !== binding.attempt_id || scope.roundId !== binding.round_id || scope.policy_version_id !== binding.policy_version_id)
        reject('NOT_AUTHORIZED');
    const stored = (await client.query<Omit<Asset, keyof Scope>>(`SELECT id,object_key,kind,state,mime_type,byte_size,sha256,version
    FROM rounds.assets WHERE tenant_id=$1 AND id=$2 AND created_by=$3 AND archived_at IS NULL ${lock ? 'FOR UPDATE' : ''}`, [auth.tenantId, id, auth.principalId])).rows[0];
    if (!stored || !['delivery_photo', 'signature'].includes(stored.kind))
        reject('NOT_AUTHORIZED');
    if (stored.kind === 'signature' && scope.receiver_contact_id !== binding.receiver_contact_id)
        reject('NOT_AUTHORIZED');
    // A receiver correction invalidates attributed signature, not a good photo.
    // Preserve the original binding rather than silently rewriting attribution.
    return { ...scope, ...stored, upload_key: binding.upload_key, receiver_contact_id: binding.receiver_contact_id };
}
// Transfer dispatch is separate from loadBoundPodAsset: SubmitProof must never
// accept a pickup issue binding as proof of a handoff.
async function asset(c: PoolClient, auth: CommandAuthority, id: string, lock = false) {
    const stored = (await c.query<{ kind: string }>('SELECT kind FROM rounds.assets WHERE tenant_id=$1 AND id=$2 AND created_by=$3 AND archived_at IS NULL', [auth.tenantId, id, auth.principalId])).rows[0];
    if (!stored) reject('NOT_AUTHORIZED');
    return stored.kind === 'issue_photo' ? loadBoundPickupIssueAsset(c, auth, id, lock) : loadBoundPodAsset(c, auth, id, lock);
}
function reservationPurpose(c: PoolClient, auth: CommandAuthority, r: Wire_ReserveAssetRequest, lock = false): Promise<Scope | PickupIssueAssetScope> {
    return r.payload.kind === 'issue_photo'
        ? pickupIssueAssetPurpose(c, auth, r.payload.purpose_entity_id, r.payload.pickup_context!, r.occurred_at, lock)
        : purpose(c, auth, r.payload.purpose_entity_id, lock);
}
// Deliberately NOT a wire ReserveAssetResult: durable receipts contain only
// identity. Fresh authorized capabilities are attached AFTER commit/status.
function validateReserveReceipt(r: CommandResult): void {
    if (r.state === 'rejected') {
        validateAssetResult(r);
        return;
    }
    const candidate = r as unknown as Wire_ReserveAssetResult;
    if (Object.keys(candidate.data ?? {}).join(',') !== 'asset_id')
        throw new Error('Unsafe asset receipt');
    validateAssetResult({ ...r, data: { asset_id: candidate.data.asset_id, upload_url: 'https://invalid.example/not-a-capability', upload_token: null, expires_at: '2026-01-01T00:00:00Z', upload_method: 'PUT' } });
}
async function fact(client: PoolClient, auth: CommandAuthority, request: Wire_ReserveAssetRequest | Wire_VerifyAssetRequest, trace: string, id: string, version: number, from: string | null, state: 'reserved' | 'verified'): Promise<void> {
    const resource = root(id, version), received = (await client.query<{
        at: Date;
    }>('SELECT clock_timestamp() AS at')).rows[0]!.at.toISOString();
    const event = { event_id: randomUUID(), event_type: `asset.${state}`, schema_version: 3, tenant_id: auth.tenantId, principal_id: null, aggregate: resource,
        occurred_at: request.occurred_at, received_at: received, actor_id: auth.principalId, command_id: request.command_id, worker_run_id: null, trace_id: trace,
        payload: { subject: resource, affected_resources: [resource], changes: [{ family: 'assets.state', resource_id: id, from_state: from, to_state: state, version }] } };
    validateAssetEvent(event);
    const e = event as Wire_Event_asset_reserved;
    await client.query(`INSERT INTO rounds.domain_events(id,tenant_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,actor_id,command_id,occurred_at,received_at,payload,trace_id)
    VALUES($1,$2,'assets',$3,$4,$5,3,$6,$7,$8,$9,$10,$11)`, [e.event_id, auth.tenantId, id, version, e.event_type, auth.principalId, request.command_id, request.occurred_at, received, JSON.stringify(e.payload), trace]);
    await client.query(`INSERT INTO rounds.outbox_events(tenant_id,event_id,destination,state,available_at) VALUES($1,$2,'audit_realtime','queued',now())`, [auth.tenantId, e.event_id]);
}
export function createPodAssets(pool: Pool, storage: PodObjectStore, retentionClass: string) {
    if (!/^[a-z][a-z0-9_-]{1,63}$/.test(retentionClass))
        throw new Error('Explicit POD retention class required');
    const runner = new CommandTransactionRunner(pool);
    async function read<T>(auth: CommandAuthority, authorize: Authorize, fn: (client: PoolClient) => Promise<T>): Promise<T> {
        const client = await pool.connect();
        let poisoned = false;
        try {
            await beginRestrictedTransaction(client, auth);
            await authorize(client, auth);
            await authorizeTeamPickupCity(client, auth);
            const value = await fn(client);
            await client.query('COMMIT');
            return value;
        }
        catch (e) {
            try {
                await client.query('ROLLBACK');
            }
            catch {
                poisoned = true;
            }
            throw e;
        }
        finally {
            client.release(poisoned);
        }
    }
    const io = <T>(work: (signal: AbortSignal) => Promise<T>): Promise<T> => {
        const controller = new AbortController();
        let timer: ReturnType<typeof setTimeout>;
        return Promise.race([Promise.resolve().then(() => work(controller.signal)), new Promise<T>((_, reject) => {
                timer = setTimeout(() => { controller.abort(); reject(new TransactionUnavailable('PROVIDER_UNAVAILABLE')); }, 15000);
            })]).finally(() => clearTimeout(timer!));
    };
    async function hydrate(result: CommandResult, authority: CommandAuthority, authorize: Authorize): Promise<CommandResult> {
        const r = snapshot(result), auth = Object.freeze({ ...authority });
        if (r.command_type !== 'ReserveAsset' || r.state === 'rejected') {
            validateAssetResult(r);
            return r;
        }
        validateReserveReceipt(r);
        const id = (r.data as {
            asset_id: string;
        }).asset_id;
        const before = await read(auth, authorize, c => asset(c, auth, id));
        if (!['reserved', 'uploading', 'uploaded', 'verified'].includes(before.state))
            reject('IMMUTABLE_RECORD');
        // Reserve replay always targets the original staging reservation, including
        // after verification. It can never grant a write to the sealed evidence key.
        const cap = await io(signal => storage.issueUpload({ key: before.upload_key, mimeType: before.mime_type, byteSize: Number(before.byte_size), sha256: before.sha256 }, signal));
        const parsed = new URL(cap.upload_url), expires = Date.parse(cap.expires_at);
        if (!(parsed.protocol === 'https:' || parsed.protocol === 'http:' && ['127.0.0.1', '[::1]'].includes(parsed.hostname)) ||
            parsed.username || parsed.password || !['PUT', 'POST'].includes(cap.upload_method) || !Number.isFinite(expires) || expires <= Date.now() || expires > Date.now() + 300000)
            throw new Error('Unsafe provider capability');
        // Never disclose a capability after device/job revocation during signing.
        const after = await read(auth, authorize, c => asset(c, auth, id));
        if (canonicalCommandJson(before) !== canonicalCommandJson(after))
            reject('NOT_AUTHORIZED');
        const response = { ...r, data: { asset_id: id, upload_url: cap.upload_url,
                upload_token: cap.upload_token, expires_at: cap.expires_at,
                upload_method: cap.upload_method } };
        validateAssetResult(response);
        return response;
    }
    async function reserve(authority: CommandAuthority, request: Wire_ReserveAssetRequest, authorize: Authorize) {
        const auth = Object.freeze({ ...authority }), r = snapshot(request);
        validateReserveAssetRequest(r);
        const work: CommandWork = { commandType: 'ReserveAsset', authority: auth, request: r, validate: validateReserveAssetRequest, validateResult: validateReserveReceipt,
            authorize: async (c, a) => { await authorize(c, a); await authorizeTeamPickupCity(c, a); }, resolveReceiptScope: c => reservationPurpose(c, auth, r),
            execute: async (c, frozen, trace, job) => {
                const request = frozen as Wire_ReserveAssetRequest, scope = await reservationPurpose(c, auth, request, true);
                if (!job || job.assignmentId !== scope.assignmentId || job.roundId !== scope.roundId)
                    reject('NOT_AUTHORIZED');
                const id = randomUUID(), p = request.payload, key = `pod-staging/${auth.tenantId}/${id}/${randomUUID()}`;
                await c.query(`INSERT INTO rounds.assets(id,tenant_id,object_key,kind,state,mime_type,byte_size,sha256,created_by,retention_class)
          VALUES($1,$2,$3,$4,'reserved',$5,$6,$7,$8,$9)`, [id, auth.tenantId, key, p.kind, p.mime_type, p.byte_size, p.sha256, auth.principalId, retentionClass]);
                if ('pickup_stop_id' in scope) await bindPickupIssueAsset(c, auth, id, scope, key);
                else await c.query(`INSERT INTO rounds.pod_asset_bindings(asset_id,tenant_id,city_id,actor_id,handoff_id,attempt_id,round_id,assignment_id,assignment_version,policy_version_id,receiver_contact_id,upload_key)
          VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`, [id, auth.tenantId, auth.cityId, auth.principalId, scope.handoff_id, scope.attempt_id, scope.roundId, scope.assignmentId, scope.assignment_version, scope.policy_version_id, scope.receiver_contact_id, key]);
                await fact(c, auth, request, trace, id, 1, null, 'reserved');
                return { command_id: request.command_id, command_type: 'ReserveAsset', state: 'committed', current_versions: [], resources: [root(id, 1)], data: { asset_id: id } };
            } };
        const outcome = await runner.run(work);
        validateReserveReceipt(outcome.result);
        return { ...outcome, result: await hydrate(outcome.result, auth, authorize) };
    }
    async function verify(authority: CommandAuthority, request: Wire_VerifyAssetRequest, authorize: Authorize) {
        const auth = Object.freeze({ ...authority }), r = snapshot(request);
        validateVerifyAssetRequest(r);
        const check: Authorize = async (c, a) => { await authorize(c, a); await authorizeTeamPickupCity(c, a); };
        // A committed/rejected receipt is replayed without downloading again, but
        // runner still checks the complete original request hash and current access.
        const prior = await runner.status(r.command_id, auth, check, async (c, receipt) => {
            if (receipt.commandType !== 'VerifyAsset')
                reject('IDEMPOTENCY_CONFLICT');
            if (!receipt.job)
                reject('NOT_AUTHORIZED');
            await authorizeTeamPickupJob(c, auth, receipt.job.roundId, receipt.job.assignmentId);
        });
        let observed: Awaited<ReturnType<typeof asset>> | undefined, sealed: string | undefined, failure: CommandRejection | undefined;
        if (!prior) {
            observed = await read(auth, authorize, c => asset(c, auth, r.payload.asset_id));
            assertExpectedVersions(r.expected_versions, [root(observed.id, Number(observed.version))]);
            if (r.payload.sha256 !== observed.sha256 || !['reserved', 'uploading', 'uploaded'].includes(observed.state))
                reject('ASSET_NOT_VERIFIED');
            try {
                const bytes = await io(async (signal) => readPodBytes(await storage.read(observed!.object_key, signal), Number(observed!.byte_size)));
                await verifyPodImage(bytes, observed.mime_type, observed.sha256);
                // Copy the checked bytes into a different server-write-only key. An old
                // staging upload token can never overwrite the evidence referenced later.
                sealed = `pod-verified/${auth.tenantId}/${observed.id}/${randomUUID()}`;
                await io(signal => storage.seal(sealed!, bytes, observed!.mime_type, signal));
                const stored = await io(async (signal) => readPodBytes(await storage.read(sealed!, signal), Number(observed!.byte_size)));
                if (podHash(stored) !== observed.sha256)
                    reject('ASSET_NOT_VERIFIED');
            }
            catch (e) {
                if (e instanceof CommandRejection)
                    failure = e;
                else
                    throw new TransactionUnavailable('PROVIDER_UNAVAILABLE');
            }
        }
        const work: CommandWork = { commandType: 'VerifyAsset', authority: auth, request: r, validate: validateVerifyAssetRequest, validateResult: validateAssetResult, authorize: check,
            resolveReceiptScope: c => asset(c, auth, r.payload.asset_id), execute: async (c, frozen, trace) => {
                const request = frozen as Wire_VerifyAssetRequest, current = await asset(c, auth, request.payload.asset_id, true);
                assertExpectedVersions(request.expected_versions, [root(current.id, Number(current.version))]);
                if (!observed)
                    throw new Error('Missing verification observation');
                if (canonicalCommandJson(current) !== canonicalCommandJson(observed))
                    reject('ASSET_NOT_VERIFIED');
                if (failure)
                    throw failure;
                if (!sealed)
                    throw new Error('Missing sealed image');
                const v = Number(current.version) + 1;
                if (!Number.isSafeInteger(v))
                    throw new Error('Unsafe asset version');
                await c.query(`UPDATE rounds.assets SET object_key=$3,state='verified',verified_at=clock_timestamp(),version=version+1,updated_at=now() WHERE tenant_id=$1 AND id=$2`, [auth.tenantId, current.id, sealed]);
                await fact(c, auth, request, trace, current.id, v, current.state, 'verified');
                const resource = root(current.id, v);
                return { command_id: request.command_id, command_type: 'VerifyAsset', state: 'committed', current_versions: [resource], resources: [], data: { resource, state: 'verified' } } satisfies Wire_VerifyAssetResult;
            } };
        const outcome = await runner.run(work);
        validateAssetResult(outcome.result);
        return outcome;
    }
    return { reserve, verify, hydrate };
}
