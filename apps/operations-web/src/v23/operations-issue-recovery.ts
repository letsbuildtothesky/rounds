/** Tab-local draft/attempt journal. Never stores tokens, projections or grants.
 * This is not an encrypted vault or an offline authorization source. The host
 * supplies sessionStorage only after verified Auth and rotates loginId on login
 * or logout (not token refresh). Browser storage is still exposed to same-origin
 * scripts; CSP/XSS protection and actual browser lifecycle tests remain required.
 */
export type TabStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;
const prefix = 'rounds:v23:pickup-reply:';
const intakePrefix = 'rounds:v23:manual-intake:';

export class IssueRecoveryError extends Error {
  constructor(readonly code: string) { super(code); }
}

export class OperationsIssueRecovery {
  #expected: string | null | undefined;
  readonly key: string;
  constructor(private storage: TabStorage, private binding: string, private loginId: string, namespace:'pickup-reply'|'manual-intake'='pickup-reply') {
    if (!loginId || loginId.length > 200) throw new IssueRecoveryError('RECOVERY_SESSION_REQUIRED');
    this.key = (namespace==='manual-intake'?intakePrefix:prefix) + binding;
  }
  read(): unknown {
    try {
      const raw = this.storage.getItem(this.key);
      this.#expected = raw;
      if (raw === null) return null;
      if (new TextEncoder().encode(raw).length > 131072) throw new IssueRecoveryError('RECOVERY_CORRUPT');
      const value = JSON.parse(raw);
      if (!value || Object.keys(value).sort().join(',') !== 'binding,loginId,value,version' ||
        value.version !== 1 || value.binding !== this.binding || typeof value.loginId !== 'string') throw new IssueRecoveryError('RECOVERY_CORRUPT');
      // A new login must never inherit another session's private instructions.
      if (value.loginId !== this.loginId) { this.clear(); return null; }
      return value.value;
    } catch (error) { throw error instanceof IssueRecoveryError ? error : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
  }
  write(value: unknown): void {
    try {
      if (this.#expected === undefined || this.storage.getItem(this.key) !== this.#expected) throw new IssueRecoveryError('RECOVERY_CONFLICT');
      const raw = JSON.stringify({version: 1, binding: this.binding, loginId: this.loginId, value});
      if (new TextEncoder().encode(raw).length > 131072) throw new IssueRecoveryError('RECOVERY_TOO_LARGE');
      this.storage.setItem(this.key, raw);
      if (this.storage.getItem(this.key) !== raw) throw new IssueRecoveryError('RECOVERY_UNAVAILABLE');
      this.#expected = raw;
    } catch (error) { throw error instanceof IssueRecoveryError ? error : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
  }
  clear(): void {
    try {
      if (this.#expected === undefined) {
        const raw = this.storage.getItem(this.key);
        // Auth teardown may precede the first successful query. Inspect only
        // this journal's ownership, not its draft contents or other namespaces.
        if (raw === null) { this.#expected = null; return; }
        const owner = JSON.parse(raw);
        if (owner?.loginId !== this.loginId || owner?.binding !== this.binding) return;
        this.#expected = raw;
      }
      // Never erase another controller's newer draft/attempt.
      if (this.#expected === undefined || this.storage.getItem(this.key) !== this.#expected) throw new IssueRecoveryError('RECOVERY_CONFLICT');
      this.storage.removeItem(this.key); this.#expected = null;
    } catch (error) { throw error instanceof IssueRecoveryError ? error : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
  }
}

/** Host Auth teardown must clear all city/date journals for the departing login,
 * even if a particular drawer is unmounted. Never call Storage.clear(). */
export function clearOperationsIssueLogin(storage: Storage, loginId: string): void {
  try {
    const keys = Array.from({length: storage.length}, (_, i) => storage.key(i)).filter((k): k is string => !!k && (k.startsWith(prefix)||k.startsWith(intakePrefix)));
    for (const key of keys) {
      const raw = storage.getItem(key);
      if (raw === null) continue;
      let value; try { value = JSON.parse(raw); } catch { throw new IssueRecoveryError('RECOVERY_CORRUPT'); }
      if (value?.loginId === loginId && storage.getItem(key) === raw) storage.removeItem(key);
    }
  } catch (error) { throw error instanceof IssueRecoveryError ? error : new IssueRecoveryError('RECOVERY_UNAVAILABLE'); }
}
