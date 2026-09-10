import {clearOperationsIssueLogin, IssueRecoveryError} from './operations-issue-recovery';

export type VerifiedIssueLogin = {subject: string; authSessionId: string; bearer: string};
type Binding = {version: 1; subject: string; authSessionId: string; loginId: string};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (value: unknown): value is string => typeof value === 'string' && uuid.test(value);

/** Called only AFTER Auth has verified this exact bearer. The decoded session
 * identifier partitions recovery, never grants API permission. Tokens stay out
 * of this record. Auth subject and domain principal are deliberately distinct. */
export function verifiedIssueLogin(bearer: string, verifiedSubject: string): VerifiedIssueLogin {
  try {
    const part = bearer.split('.')[1]!;
    const claims = JSON.parse(atob(part.replace(/-/g, '+').replace(/_/g, '/')));
    if (claims.sub !== verifiedSubject || !isUuid(claims.session_id) ||
      !Number.isFinite(claims.exp) || claims.exp * 1000 <= Date.now()) throw new Error();
    return {subject: verifiedSubject, authSessionId: claims.session_id, bearer};
  } catch { throw new IssueRecoveryError('AUTH_SESSION_UNAVAILABLE'); }
}

export class OperationsIssueLogin {
  readonly key: string;
  constructor(private storage: Storage, authOrigin: string, apiOrigin: string) {
    this.key = 'rounds:v23:pickup-login:' + JSON.stringify([authOrigin, apiOrigin]);
  }
  #read(): Binding | null {
    const raw = this.storage.getItem(this.key);
    if (raw === null) return null;
    if (raw.length > 2048) throw new IssueRecoveryError('RECOVERY_CORRUPT');
    let value; try { value = JSON.parse(raw); } catch { throw new IssueRecoveryError('RECOVERY_CORRUPT'); }
    if (!value || Object.keys(value).sort().join(',') !== 'authSessionId,loginId,subject,version' ||
      value.version !== 1 || !isUuid(value.subject) || !isUuid(value.authSessionId) || !isUuid(value.loginId)) throw new IssueRecoveryError('RECOVERY_CORRUPT');
    return value;
  }
  bind(verified: VerifiedIssueLogin): string {
    try {
      if (!isUuid(verified.subject) || !isUuid(verified.authSessionId) || !verified.bearer) throw new IssueRecoveryError('AUTH_SESSION_UNAVAILABLE');
      const previous = this.#read();
      if (previous?.subject === verified.subject && previous.authSessionId === verified.authSessionId) return previous.loginId;
      if (previous) clearOperationsIssueLogin(this.storage, previous.loginId);
      const next: Binding = {version: 1, subject: verified.subject, authSessionId: verified.authSessionId, loginId: crypto.randomUUID()};
      const raw = JSON.stringify(next);
      this.storage.setItem(this.key, raw);
      if (this.storage.getItem(this.key) !== raw) throw new IssueRecoveryError('RECOVERY_UNAVAILABLE');
      return next.loginId;
    } catch (e) { throw e instanceof IssueRecoveryError ? e : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
  }
  clear(): void {
    try {
      const previous = this.#read();
      if (previous) clearOperationsIssueLogin(this.storage, previous.loginId);
      this.storage.removeItem(this.key);
      if (this.storage.getItem(this.key) !== null) throw new IssueRecoveryError('RECOVERY_UNAVAILABLE');
    } catch (e) { throw e instanceof IssueRecoveryError ? e : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
  }
}
