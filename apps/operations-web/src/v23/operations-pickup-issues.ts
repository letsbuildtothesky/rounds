import type { Wire_OperationsPickupIssuesQueryResult, Wire_ResolveIssueRequest } from '../../../../packages/contracts/src/v23/pickup-wire.js';
import { validBoard, validRequest, validResult, validRejected, validError } from './generated/operations-issue-validation.cjs';
import { OperationsIssueRecovery, IssueRecoveryError, type TabStorage } from './operations-issue-recovery';

type Snapshot = Wire_OperationsPickupIssuesQueryResult;
export type PickupIssue = Snapshot['data']['issues'][number];
export type OperationsIssueScope = Readonly<{principalId: string; tenantId: string; cityId: string; serviceDate: string; sessionEpoch: number}>;
type Session = {principalId: string; sessionEpoch: number; bearer: string};
type Draft = Readonly<{issueId: string; issueVersion: number; roundId: string; assignmentId: string; assignmentVersion: number;
  deliveryId: string | null; action: 'wait' | 'escalate'; instructions: string; reason: string}>;
type Pending = {request: Wire_ResolveIssueRequest; bytes: string};
const errorCode = (e: unknown, fallback: string) => e instanceof OperationsIssueError || e instanceof IssueRecoveryError ? e.code : fallback;
export class OperationsIssueError extends Error {
  constructor(readonly code: string) { super(code); }
}
const freeze = <T>(value: T): T => {
  if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
};

/** Browser-side state/transport for the approved host drawer. No demo fallback,
 * artwork, localStorage or activation of the legacy workstation. Optional
 * sessionStorage recovery never restores a cached projection/permission.
 * The host closes/disposes on Auth, tenant, city or date change. Every await also
 * checks the originating identity epoch; token renewal alone may preserve it. */
export class OperationsPickupIssues {
  readonly scope: OperationsIssueScope;
  #base: string;
  #session: () => Session | null;
  #fetch: typeof fetch;
  #includeDisplay: boolean;
  #closed = false;
  #phase: 'idle' | 'loading' | 'ready' | 'failed' | 'closed' = 'idle';
  #snapshot: Snapshot | null = null;
  #error: string | null = null;
  #reading: Promise<void> | null = null;
  #pending: Pending | null = null;
  #draft: Draft | null = null;
  #journal: OperationsIssueRecovery | null = null;
  #login: (() => boolean) | null = null;
  #restored = false;
  #storageError: string | null = null;
  #committedVersions = new Map<string, number>();
  #sending = false;
  #controllers = new Set<AbortController>();
  #listeners = new Set<() => void>();

  constructor(options: {baseUrl: string; scope: OperationsIssueScope; session: () => Session | null; fetch?: typeof fetch; includeDisplay?: boolean;
    recovery?: {storage: TabStorage; loginId: string; currentLoginId: () => string | null}}) {
    const url = new URL(options.baseUrl);
    if (url.username || url.password || url.search || url.hash || url.pathname !== '/' ||
      url.protocol !== 'https:' && !(url.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname))) throw new OperationsIssueError('INVALID_ORIGIN');
    this.#base = url.origin; this.scope = Object.freeze({...options.scope}); this.#session = options.session;
    // Native browser fetch must retain its Window receiver, not this controller.
    this.#fetch = options.fetch ?? ((input, init) => globalThis.fetch(input, init));
    this.#includeDisplay = options.includeDisplay === true;
    if (options.recovery) {
      const {storage, loginId, currentLoginId} = options.recovery;
      this.#journal = new OperationsIssueRecovery(storage, JSON.stringify([this.#base, this.scope.principalId, this.scope.tenantId, this.scope.cityId, this.scope.serviceDate]), loginId);
      this.#login = () => currentLoginId() === loginId;
    }
  }
  #live(): boolean {
    const s = this.#session();
    if (!this.#closed && s?.principalId === this.scope.principalId && s.sessionEpoch === this.scope.sessionEpoch && s.bearer && (this.#login?.() ?? true)) return true;
    if (!this.#closed) this.dispose(true); return false;
  }
  #requireLive(): void { if (!this.#live()) throw new OperationsIssueError('SESSION_CHANGED'); }
  get state() {
    this.#live();
    return Object.freeze({phase: this.#phase, snapshot: this.#snapshot, errorCode: this.#error,
      lastKnown: this.#snapshot !== null && this.#phase !== 'ready', sending: this.#sending,
      pendingCommandId: this.#pending?.request.command_id ?? null, draft: this.#draft,
      draftNeedsReview: !!this.#draft && !this.#draftCurrent(),
      hasUnsavedWork: this.#draft !== null || this.#pending !== null,
      reloadRecovery: this.#journal !== null, recoveryError: this.#storageError});
  }
  subscribe(listener: () => void): () => void { this.#listeners.add(listener); return () => this.#listeners.delete(listener); }
  #notify() { for (const listener of this.#listeners) listener(); }
  dispose(clearRecovery = false): void {
    if (this.#closed) return;
    if (clearRecovery && this.#journal) {
      try { this.#journal.clear(); } catch (e) { this.#storageError = errorCode(e, 'RECOVERY_UNAVAILABLE'); }
    }
    this.#closed = true; this.#phase = 'closed'; this.#snapshot = null; this.#pending = null; this.#draft = null; this.#error = null; this.#sending = false;
    this.#committedVersions.clear();
    for (const controller of this.#controllers) controller.abort();
    this.#notify(); this.#listeners.clear();
  }
  async #request(path: string, body?: string): Promise<{status: number; data: any}> {
    this.#requireLive(); const session = this.#session()!;
    const controller = new AbortController(); this.#controllers.add(controller);
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await this.#fetch(this.#base + path, {method: body === undefined ? 'GET' : 'POST',
        headers: {authorization: `Bearer ${session.bearer}`, ...(body === undefined ? {} : {'content-type': 'application/json'})},
        ...(body === undefined ? {} : {body}), cache: 'no-store', credentials: 'omit', redirect: 'error', signal: controller.signal});
      this.#requireLive();
      if ([401, 403].includes(response.status)) { this.dispose(true); throw new OperationsIssueError('NOT_AUTHORIZED'); }
      if (!response.body) throw new OperationsIssueError('INVALID_RESPONSE');
      const reader = response.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
      try {
        while (true) { const part = await reader.read(); this.#requireLive(); if (part.done) break;
          size += part.value.byteLength; if (size > 65536) throw new OperationsIssueError('INVALID_RESPONSE'); chunks.push(part.value); }
      } finally { await reader.cancel(); }
      const bytes = new Uint8Array(size); let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      let data: unknown; try { data = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes)); }
      catch { throw new OperationsIssueError('INVALID_RESPONSE'); }
      this.#requireLive(); return {status: response.status, data};
    } finally { clearTimeout(timer); this.#controllers.delete(controller); }
  }
  #filters(): URLSearchParams { return new URLSearchParams({tenant_id: this.scope.tenantId, city_id: this.scope.cityId}); }
  refresh(): Promise<void> {
    this.#requireLive(); if (this.#reading) return this.#reading;
    this.#phase = 'loading'; this.#error = null;
    // Install coalescing latch before observers can synchronously refresh.
    this.#reading = Promise.resolve().then(async () => {
      try {
        const params = this.#filters(); params.set('view', 'pickup_issues'); params.set('service_date', this.scope.serviceDate);
        if (this.#includeDisplay) params.set('display', 'labels');
        const response = await this.#request('/v1/queries/Board?' + params);
        if (response.status !== 200 || !validBoard(response.data)) throw new OperationsIssueError('SOURCE_UNAVAILABLE');
        const value = response.data as Snapshot, data = value.data;
        if (this.#includeDisplay && data.issues.some(issue => !issue.display)) throw new OperationsIssueError('SOURCE_UNAVAILABLE');
        if (data.principal_id !== this.scope.principalId || data.tenant_id !== this.scope.tenantId || data.city_id !== this.scope.cityId || data.service_date !== this.scope.serviceDate ||
          new Set(data.issues.map(i => i.issue_id)).size !== data.issues.length) throw new OperationsIssueError('INVALID_RESPONSE');
        for (const issue of data.issues) {
          if (issue.issue_version < (this.#committedVersions.get(issue.issue_id) ?? 0)) throw new OperationsIssueError('SOURCE_STALE');
          const old = this.#snapshot?.data.issues.find(i => i.issue_id === issue.issue_id);
          if (old && (issue.issue_version < old.issue_version || issue.assignment_id !== old.assignment_id || issue.assignment_version !== old.assignment_version || issue.round_id !== old.round_id || issue.delivery_id !== old.delivery_id)) throw new OperationsIssueError('SOURCE_STALE');
          if (issue.allowed_actions.length && issue.blocked_reason !== null || !issue.allowed_actions.length && issue.blocked_reason === null) throw new OperationsIssueError('INVALID_RESPONSE');
          if (issue.state === 'resolved' && issue.allowed_actions.length ||
            ['decided', 'resolved'].includes(issue.state) !== (issue.decisions.length === 1)) throw new OperationsIssueError('INVALID_RESPONSE');
        }
        // No private draft is revealed before a fresh authorized scoped read.
        this.#restore();
        for (const issue of data.issues) if (issue.issue_version < (this.#committedVersions.get(issue.issue_id) ?? 0)) throw new OperationsIssueError('SOURCE_STALE');
        this.#snapshot = freeze(value); this.#phase = 'ready';
      } catch (e) {
        if (this.#live()) { this.#phase = 'failed'; this.#error = errorCode(e, 'SOURCE_UNAVAILABLE'); }
      } finally { this.#reading = null; this.#notify(); }
    });
    this.#notify(); return this.#reading!;
  }
  async send(issueId: string, action: 'wait' | 'escalate', instructions: string, reason: string): Promise<void> {
    this.saveDraft(issueId, action, instructions, reason);
    await this.submitDraft();
  }
  #draftCurrent(): boolean {
    const d = this.#draft, i = this.#snapshot?.data.issues.find(i => i.issue_id === d?.issueId);
    return !!d && this.#phase === 'ready' && !!i && i.issue_version === d.issueVersion && i.round_id === d.roundId &&
      i.assignment_id === d.assignmentId && i.assignment_version === d.assignmentVersion && i.delivery_id === d.deliveryId && i.allowed_actions.includes(d.action);
  }
  saveDraft(issueId: string, action: 'wait' | 'escalate', instructions: string, reason: string): void {
    this.#requireLive();
    if (this.#pending || this.#sending) throw new OperationsIssueError('RESULT_PENDING');
    const issue = this.#snapshot?.data.issues.find(i => i.issue_id === issueId);
    if (this.#phase !== 'ready' || !issue?.allowed_actions.includes(action)) throw new OperationsIssueError('SOURCE_STALE');
    if (this.#draft && (!this.#draftCurrent() || this.#draft.issueId !== issueId)) throw new OperationsIssueError('DRAFT_REVIEW_REQUIRED');
    if (typeof instructions !== 'string' || typeof reason !== 'string' || [...instructions].length > 4000 || [...reason].length > 4000) throw new OperationsIssueError('VALIDATION_FAILED');
    this.#draft = freeze({issueId, issueVersion: issue.issue_version, roundId: issue.round_id, assignmentId: issue.assignment_id,
      assignmentVersion: issue.assignment_version, deliveryId: issue.delivery_id, action, instructions, reason});
    try { this.#persist(); } finally { this.#notify(); }
  }
  discardDraft(): void {
    this.#requireLive(); if (this.#pending || this.#sending) throw new OperationsIssueError('RESULT_PENDING');
    const old = this.#draft;
    this.#draft = null; try { this.#persist(); } catch (e) { this.#draft = old; throw e; } finally { this.#notify(); }
  }
  async submitDraft(): Promise<void> {
    this.#requireLive();
    if (this.#pending || this.#sending) throw new OperationsIssueError('RESULT_PENDING');
    if (!this.#draftCurrent()) throw new OperationsIssueError('SOURCE_STALE');
    const draft = this.#draft!;
    const request: Wire_ResolveIssueRequest = {command_id: crypto.randomUUID(), context: {tenant_id: this.scope.tenantId, city_id: this.scope.cityId},
      occurred_at: new Date().toISOString(), expected_versions: [{aggregate_type: 'issues', id: draft.issueId, version: draft.issueVersion}],
      payload: {issue_id: draft.issueId, decision: {action: draft.action, instructions: draft.instructions, quantities: []}, reason: draft.reason}};
    if (!validRequest(request) || !draft.instructions.trim() || !draft.reason.trim()) throw new OperationsIssueError('VALIDATION_FAILED');
    const bytes = JSON.stringify(request);
    if (new TextEncoder().encode(bytes).length > 65536) throw new OperationsIssueError('VALIDATION_FAILED');
    this.#pending = {request: freeze(request), bytes};
    // Save before the first network byte. If storage is uncertain, do not POST.
    try { this.#persist(); } catch (e) { this.#notify(); throw e; }
    await this.#submit(false);
  }
  async retry(): Promise<void> {
    this.#requireLive(); if (!this.#pending || this.#sending) throw new OperationsIssueError('NO_RETRY_AVAILABLE');
    if (this.#storageError) throw new OperationsIssueError(this.#storageError);
    await this.#submit(true);
  }
  async #submit(recover: boolean): Promise<void> {
    this.#sending = true; this.#error = null; this.#notify();
    const pending = this.#pending!;
    try {
      let response;
      if (recover) {
        const params = this.#filters(); params.set('entity_id', pending.request.command_id);
        response = await this.#request('/v1/queries/CommandStatus?' + params);
        if (response.status === 200) {
          // Exact status envelope, never treat an arbitrary nested object as a receipt.
          if (!response.data || Object.keys(response.data).sort().join(',') !== 'as_of,data,next_cursor' ||
            !Number.isFinite(Date.parse(response.data.as_of)) || response.data.next_cursor !== null ||
            Object.keys(response.data.data ?? {}).join(',') !== 'result') throw new OperationsIssueError('UNKNOWN_RESULT');
          response = {status: 200, data: response.data.data.result};
        } else if (response.status === 404 && validError(response.data) && response.data.code === 'NOT_FOUND') response = undefined;
        else throw new OperationsIssueError('UNKNOWN_RESULT');
      }
      response ??= await this.#request('/v1/commands/ResolveIssue', pending.bytes);
      const result = response.data;
      if (response.status === 200 && (validResult(result) || validRejected(result)) && result.command_type === 'ResolveIssue' && result.command_id === pending.request.command_id) {
        if (result.state === 'committed') {
          if (result.data.resource.id !== pending.request.payload.issue_id || result.data.resource.version !== pending.request.expected_versions[0]!.version + 1) throw new OperationsIssueError('UNKNOWN_RESULT');
          this.#committedVersions.set(pending.request.payload.issue_id, result.data.resource.version);
          this.#settle(true);
          // A read started before the POST cannot certify the committed reply.
          if (this.#reading) await this.#reading;
          this.#requireLive(); await this.refresh(); return;
        }
        this.#settle(false); this.#phase = 'failed'; this.#error = result.error.code;
      } else if (response.status >= 400 && response.status < 500 && response.status !== 429 && validError(result)) {
        this.#settle(false); this.#phase = 'failed'; this.#error = result.code;
      } else throw new OperationsIssueError('UNKNOWN_RESULT');
    } catch (e) {
      if (this.#live()) { this.#phase = 'failed'; this.#error = errorCode(e, 'UNKNOWN_RESULT'); }
    } finally { this.#sending = false; this.#notify(); }
  }
  #settle(committed: boolean): void {
    const pending = this.#pending, draft = this.#draft;
    this.#pending = null; if (committed) this.#draft = null;
    try { this.#persist(); } catch (e) { this.#pending = pending; this.#draft = draft; throw e; }
  }
  #persist(): void {
    if (!this.#journal) return;
    if (this.#storageError) throw new OperationsIssueError(this.#storageError);
    try {
      if (this.#committedVersions.size > 200) throw new OperationsIssueError('RECOVERY_TOO_LARGE');
      this.#journal.write({draft: this.#draft, pending: this.#pending?.bytes ?? null, committed: [...this.#committedVersions]});
    }
    catch (e) { this.#storageError = errorCode(e, 'RECOVERY_UNAVAILABLE'); this.#phase = 'failed'; this.#error = this.#storageError; throw e; }
  }
  #restore(): void {
    if (this.#storageError) throw new OperationsIssueError(this.#storageError);
    if (this.#restored || !this.#journal) return;
    try {
      const value: any = this.#journal.read();
      let draft: Draft | null = null, pending: Pending | null = null;
      const versions = new Map<string, number>();
      if (value !== null) {
        const bad = () => { throw new OperationsIssueError('RECOVERY_CORRUPT'); };
        const uuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
        const version = (v: unknown) => Number.isSafeInteger(v) && Number(v) > 0;
        if (!value || Object.keys(value).sort().join(',') !== 'committed,draft,pending' || !Array.isArray(value.committed) || value.committed.length > 200) bad();
        for (const entry of value.committed) {
          if (!Array.isArray(entry) || entry.length !== 2 || !uuid(entry[0]) || !version(entry[1]) || versions.has(entry[0])) bad();
          versions.set(entry[0], entry[1]);
        }
        const d = value.draft;
        if (d !== null) {
          if (!d || Object.keys(d).sort().join(',') !== 'action,assignmentId,assignmentVersion,deliveryId,instructions,issueId,issueVersion,reason,roundId' ||
            ![d.issueId, d.roundId, d.assignmentId].every(uuid) || d.deliveryId !== null && !uuid(d.deliveryId) ||
            !version(d.issueVersion) || !version(d.assignmentVersion) || !['wait', 'escalate'].includes(d.action) ||
            typeof d.instructions !== 'string' || [...d.instructions].length > 4000 || typeof d.reason !== 'string' || [...d.reason].length > 4000) bad();
          draft = freeze(d);
        }
        if (value.pending !== null) {
          if (typeof value.pending !== 'string' || new TextEncoder().encode(value.pending).length > 65536 || !draft) bad();
          const r: any = JSON.parse(value.pending);
          if (!validRequest(r) || r.context.tenant_id !== this.scope.tenantId || r.context.city_id !== this.scope.cityId ||
            r.payload.issue_id !== draft!.issueId || r.expected_versions.length !== 1 || r.expected_versions[0].aggregate_type !== 'issues' ||
            r.expected_versions[0].id !== draft!.issueId || r.expected_versions[0].version !== draft!.issueVersion ||
            r.payload.decision.action !== draft!.action || r.payload.decision.instructions !== draft!.instructions || r.payload.reason !== draft!.reason ||
            r.payload.decision.quantities.length !== 0 || !r.payload.reason.trim() || !r.payload.decision.instructions.trim() ||
            Object.keys(r.payload).sort().join(',') !== 'decision,issue_id,reason' || Object.keys(r.payload.decision).sort().join(',') !== 'action,instructions,quantities') bad();
          pending = {request: freeze(r), bytes: value.pending};
        }
      }
      this.#draft = draft; this.#pending = pending; this.#committedVersions = versions; this.#restored = true;
    } catch (e) { this.#storageError = errorCode(e, 'RECOVERY_CORRUPT'); throw new OperationsIssueError(this.#storageError); }
  }
}
