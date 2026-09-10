import pg from "pg";

/** Explicit server-only connection configuration, never PG* environment defaults
 * or the legacy Supabase administrative credential. Constructing does not enable
 * a route or apply schema. Credentials must name a restricted login; the runner
 * additionally rejects superuser/BYPASSRLS/owner sessions at runtime.
 */
export function createCommandPool(options: {
  databaseUrl: string;
  trustedCa?: string;
  allowLocalPlaintext?: boolean;
  onIdleConnectionFailure: () => void;
}): pg.Pool {
  let url: URL;
  try { url = new URL(options.databaseUrl); } catch { throw new Error("Invalid private command database configuration"); }
  const port = url.port ? Number(url.port) : 5432;
  const host = url.hostname.replace(/^\[|\]$/g, "");
  if (!["postgres:", "postgresql:"].includes(url.protocol) || !url.username || !url.password ||
      !host || !/^\/[^/]+$/.test(url.pathname) || url.search || url.hash || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("Explicit private database, credentials and unambiguous TLS configuration required");
  }
  const plaintext = options.allowLocalPlaintext === true;
  if (plaintext && host !== "127.0.0.1" && host !== "::1") throw new Error("Plaintext is allowed only for explicit loopback test databases");
  const ssl = plaintext ? false : { rejectUnauthorized: true, ...(options.trustedCa ? { ca: options.trustedCa } : {}) };
  // Separate fields prevent URI sslmode parameters from overriding verification.
  const pool = new pg.Pool({ host, port, user: decodeURIComponent(url.username), password: decodeURIComponent(url.password),
    database: decodeURIComponent(url.pathname.slice(1)), ssl, max: 4, connectionTimeoutMillis: 3000, idleTimeoutMillis: 30000,
    application_name: "rounds-command-v23", statement_timeout: 5000 });
  pool.on("error", () => options.onIdleConnectionFailure()); // never forward/log URI or raw SQL error
  return pool;
}
