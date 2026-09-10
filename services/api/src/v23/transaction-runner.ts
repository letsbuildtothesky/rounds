import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import type { Pool, PoolClient } from "pg";
import { beginRestrictedTransaction } from './restricted-transaction.js';
import { canonicalCommandJson, commandRequestHash } from "./command-identity.js";
import { v23ErrorCodes, type V23CommandType, type V23ErrorCode } from "../../../../packages/contracts/src/v23/command-metadata.js";

export type VersionRoot = Readonly<{ aggregate_type: string; id: string; version: number }>;
export type ExecutionFence = Readonly<{ assignment_id: string; assignment_version: number; observation_id: string }>;
export type CommandRequest = Readonly<{
  command_id: string;
  context: Readonly<{ tenant_id: string | null; city_id?: string | null }>;
  occurred_at: string;
  expected_versions: readonly VersionRoot[];
  payload: unknown;
  execution_fence?: ExecutionFence;
}>;
/** Server-authenticated identity, never assembled from request headers/body. */
export type CommandAuthority = Readonly<{ principalId: string; tenantId: string | null; cityId: string | null }>;
export type ReceiptJobScope = Readonly<{ roundId: string; assignmentId: string }>;
export type ReceiptAccess = Readonly<{ commandType: string; job: ReceiptJobScope | null }>;
export type CommandResult = {
  command_id: string; command_type: string;
  state: "committed" | "queued" | "retained_for_review" | "rejected";
  [key: string]: unknown;
};
export class CommandRejection extends Error {
  constructor(readonly code: V23ErrorCode) {
    super(code);
    if (!(v23ErrorCodes as readonly string[]).includes(code)) throw new TypeError("Unknown command error code");
  }
}
export class TransactionUnavailable extends Error {
  constructor(readonly code: "UNKNOWN_RESULT" | "PROVIDER_UNAVAILABLE") { super(code); }
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const transient = new Set(["40001", "40P01"]);
const constraint = new Set(["23502", "23503", "23505", "23514", "23P01"]);
const sqlCode = (error: unknown): string | undefined => typeof error === "object" && error !== null && "code" in error ? String(error.code) : undefined;

function validateAuthority(request: CommandRequest, authority: CommandAuthority): void {
  if (!uuid.test(authority.principalId) || (authority.tenantId !== null && !uuid.test(authority.tenantId)) ||
      (authority.cityId !== null && !uuid.test(authority.cityId))) throw new CommandRejection("NOT_AUTHORIZED");
  if (request.context.tenant_id !== authority.tenantId || (request.context.city_id ?? null) !== authority.cityId) throw new CommandRejection("NOT_AUTHORIZED");
  if (!uuid.test(request.command_id) || !Number.isFinite(Date.parse(request.occurred_at))) throw new CommandRejection("VALIDATION_FAILED");
  if (!Array.isArray(request.expected_versions) || request.expected_versions.length > 1000) throw new CommandRejection("VALIDATION_FAILED");
  const roots = new Set<string>();
  for (const root of request.expected_versions) {
    const key = `${root.aggregate_type}:${root.id}`;
    if (!/^[a-z_]+$/.test(root.aggregate_type) || !uuid.test(root.id) || !Number.isSafeInteger(root.version) || root.version <= 0 || roots.has(key)) throw new CommandRejection("VALIDATION_FAILED");
    roots.add(key);
  }
}

/** Call only after locking/resolving the exact authorized roots in canonical order. */
export function assertExpectedVersions(expected: readonly VersionRoot[], locked: readonly VersionRoot[]): void {
  const actual = new Map(locked.map((r) => [`${r.aggregate_type}:${r.id}`, r.version]));
  if (actual.size !== locked.length || actual.size !== expected.length || new Set(expected.map((r) => `${r.aggregate_type}:${r.id}`)).size !== expected.length) throw new CommandRejection("VALIDATION_FAILED");
  for (const root of expected) {
    const version = actual.get(`${root.aggregate_type}:${root.id}`);
    if (version === undefined) throw new CommandRejection("VALIDATION_FAILED");
    if (version !== root.version) throw new CommandRejection("STALE_VERSION");
  }
}
export function assertExecutionFence(original: ExecutionFence, locked: { assignment_id: string; assignment_version: number }): void {
  if (original.assignment_id !== locked.assignment_id || original.assignment_version !== locked.assignment_version) throw new CommandRejection("EXECUTION_FENCE_CHANGED");
}

export interface CommandWork {
  commandType: V23CommandType;
  request: CommandRequest;
  authority: CommandAuthority;
  /** Server-authorized original job; never derived from the eventual result. */
  receiptScope?: ReceiptJobScope;
  /** For attempt-addressed commands, resolve the original job inside this same
   * authorized transaction, before receipt access. Never trust a client Round. */
  resolveReceiptScope?: (client: PoolClient, authority: CommandAuthority) => Promise<ReceiptJobScope>;
  /** Exact generated wire/payload/root validator is required before enabling a handler. */
  validate: (request: CommandRequest) => void;
  /** Read/lock current membership/city/capability before receipt access; no mutations or provider calls. */
  authorize: (client: PoolClient, authority: CommandAuthority) => Promise<void>;
  /** Pinned client only. Lock domain roots in E04 order; return a sanitized schema-validated result. */
  execute: (client: PoolClient, request: CommandRequest, traceId: string, job?: ReceiptJobScope) => Promise<CommandResult>;
  validateResult: (result: CommandResult) => void;
}

/** Shared foundation, not a public command endpoint or business pickup handler. */
export class CommandTransactionRunner {
  constructor(private readonly pool: Pool) {}

  private async begin(client: PoolClient, authority: CommandAuthority): Promise<void> {
    await beginRestrictedTransaction(client,authority);
  }

  async run(work: CommandWork): Promise<{ result: CommandResult; replayed: boolean }> {
    // Snapshot before the first await: caller/validator cannot alter the bytes
    // after hashing while this command waits for a connection or row lock.
    try {
      const request = JSON.parse(canonicalCommandJson(work.request)) as CommandRequest;
      const freeze = (v: unknown): void => {
        if (v !== null && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
      };
      freeze(request);
      work = { ...work, request, authority: Object.freeze({ ...work.authority }),
        ...(work.receiptScope ? { receiptScope: Object.freeze({...work.receiptScope}) } : {}) };
    } catch { throw new CommandRejection("VALIDATION_FAILED"); }
    work.validate(work.request);
    validateAuthority(work.request, work.authority);
    if (work.receiptScope && (!uuid.test(work.receiptScope.roundId) || !uuid.test(work.receiptScope.assignmentId))) throw new CommandRejection('VALIDATION_FAILED');
    let hash: string;
    try { hash = commandRequestHash(work.commandType, work.request); }
    catch { throw new CommandRejection("VALIDATION_FAILED"); }
    const scope = `${work.authority.principalId.toLowerCase()}:${work.authority.tenantId?.toLowerCase() ?? "global"}`;
    const traceId = randomUUID();
    for (let attempt = 0; attempt < 3; attempt++) {
      let client: PoolClient;
      try { client = await this.pool.connect(); } catch { throw new TransactionUnavailable("PROVIDER_UNAVAILABLE"); }
      let poisoned = false;
      let committing = false;
      try {
        await this.begin(client, work.authority);
        await work.authorize(client, work.authority);
        if (work.receiptScope && work.resolveReceiptScope) throw new Error('Ambiguous receipt scope');
        const job = work.resolveReceiptScope ? Object.freeze({...await work.resolveReceiptScope(client, work.authority)}) : work.receiptScope;
        if (job && (!uuid.test(job.roundId) || !uuid.test(job.assignmentId))) throw new Error('Invalid resolved receipt scope');
        const inserted = await client.query(`INSERT INTO rounds.command_receipts
          (scope_key,actor_id,tenant_id,command_key,command_type,request_hash,city_id,authorization_round_id,authorization_assignment_id,state,started_at)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'in_progress',clock_timestamp())
          ON CONFLICT (scope_key,command_key) DO NOTHING RETURNING id`,
          [scope,work.authority.principalId,work.authority.tenantId,work.request.command_id,work.commandType,hash,work.authority.cityId,
            job?.roundId ?? null,job?.assignmentId ?? null]);
        const existing = await client.query(`SELECT id,request_hash,command_type,result,authorization_round_id,authorization_assignment_id FROM rounds.command_receipts
          WHERE scope_key=$1 AND command_key=$2 AND actor_id=$3 AND tenant_id IS NOT DISTINCT FROM $4::uuid AND city_id IS NOT DISTINCT FROM $5::uuid FOR UPDATE`,
          [scope,work.request.command_id,work.authority.principalId,work.authority.tenantId,work.authority.cityId]);
        const receipt = existing.rows[0];
        if (!receipt) throw new CommandRejection("NOT_AUTHORIZED");
        if (receipt.request_hash !== hash || receipt.command_type !== work.commandType) throw new CommandRejection("IDEMPOTENCY_CONFLICT");
        if (job && (receipt.authorization_round_id !== job.roundId ||
            receipt.authorization_assignment_id !== job.assignmentId)) throw new CommandRejection('UPGRADE_REQUIRED');
        if (!inserted.rowCount) {
          if (!receipt.result) throw new TransactionUnavailable("UNKNOWN_RESULT");
          committing = true;
          await client.query("COMMIT");
          return { result: receipt.result as CommandResult, replayed: true };
        }
        await client.query("SAVEPOINT domain_work");
        let result: CommandResult;
        try {
          result = await work.execute(client, work.request, traceId, job);
          if (result.command_id !== work.request.command_id || result.command_type !== work.commandType || !["committed", "queued", "retained_for_review"].includes(result.state)) throw new Error("Invalid handler result identity");
          work.validateResult(result);
          result = JSON.parse(canonicalCommandJson(result)) as CommandResult;
          // Force deferred quantity/FK guards before persisting a successful receipt.
          await client.query("SET CONSTRAINTS ALL IMMEDIATE");
          await client.query("RELEASE SAVEPOINT domain_work");
        } catch (error) {
          if (!(error instanceof CommandRejection) && !constraint.has(sqlCode(error) ?? "")) throw error;
          await client.query("ROLLBACK TO SAVEPOINT domain_work");
          await client.query("RELEASE SAVEPOINT domain_work");
          const code = error instanceof CommandRejection ? error.code : "VALIDATION_FAILED";
          result = { command_id: work.request.command_id, command_type: work.commandType, state: "rejected",
            error: { code, message_key: `errors.${code.toLowerCase()}`, retryable: false, trace_id: traceId } };
        }
        await client.query(`UPDATE rounds.command_receipts SET state=$2,result=$3::jsonb,error_code=$4,
          completed_at=clock_timestamp(),updated_at=clock_timestamp(),version=version+1 WHERE id=$1`,
          [receipt.id,result.state,JSON.stringify(result),result.state === "rejected" ? (result.error as { code: string }).code : null]);
        committing = true;
        await client.query("COMMIT");
        return { result, replayed: false };
      } catch (error) {
        try { await client.query("ROLLBACK"); } catch { poisoned = true; }
        const code = sqlCode(error);
        if (committing && !transient.has(code ?? "")) {
          poisoned = true;
          throw new TransactionUnavailable("UNKNOWN_RESULT");
        }
        if (transient.has(code ?? "") && attempt < 2 && !poisoned) {
          await delay(10 * (attempt + 1));
          continue;
        }
        if (error instanceof CommandRejection || error instanceof TransactionUnavailable) throw error;
        throw new TransactionUnavailable("PROVIDER_UNAVAILABLE");
      } finally {
        client.release(poisoned);
      }
    }
    throw new TransactionUnavailable("PROVIDER_UNAVAILABLE");
  }

  async status(commandId: string, authority: CommandAuthority, authorize: CommandWork["authorize"],
    authorizeReceipt?: (client: PoolClient, receipt: ReceiptAccess) => Promise<void>): Promise<CommandResult | null> {
    authority = Object.freeze({ ...authority });
    if (!uuid.test(commandId) || !uuid.test(authority.principalId) || (authority.tenantId !== null && !uuid.test(authority.tenantId)) ||
        (authority.cityId !== null && !uuid.test(authority.cityId))) throw new CommandRejection("VALIDATION_FAILED");
    let client: PoolClient;
    try { client = await this.pool.connect(); } catch { throw new TransactionUnavailable("PROVIDER_UNAVAILABLE"); }
    let poisoned = false;
    try {
      await this.begin(client, authority);
      await authorize(client, authority);
      const row = await client.query("SELECT result,command_type,authorization_round_id,authorization_assignment_id FROM rounds.command_receipts WHERE command_key=$1 AND actor_id=$2 AND tenant_id IS NOT DISTINCT FROM $3::uuid AND city_id IS NOT DISTINCT FROM $4::uuid",
        [commandId,authority.principalId,authority.tenantId,authority.cityId]);
      const receipt = row.rows[0];
      if (receipt && authorizeReceipt) await authorizeReceipt(client, {commandType:receipt.command_type,
        job: receipt.authorization_round_id && receipt.authorization_assignment_id
          ? {roundId:receipt.authorization_round_id,assignmentId:receipt.authorization_assignment_id} : null});
      await client.query("COMMIT");
      return (row.rows[0]?.result as CommandResult | undefined) ?? null;
    } catch (error) {
      try { await client.query("ROLLBACK"); } catch { poisoned = true; }
      if (error instanceof CommandRejection) throw error;
      throw new TransactionUnavailable("PROVIDER_UNAVAILABLE");
    } finally { client.release(poisoned); }
  }
}
