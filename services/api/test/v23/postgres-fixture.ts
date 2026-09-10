/** Real temporary PostgreSQL, never a supplied URL or the shared Supabase database.
 * Only five NON-SPATIAL source tables are installed. This is not the full
 * PostGIS schema/migration/131-command acceptance environment.
 */
import { randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import EmbeddedPostgres from "embedded-postgres";
import pg from "pg";

const source = new URL("../../../../specs/source/Rounds-Complete-Project-v2.3/specs/database/", import.meta.url);
const sourceTables = ["tenants", "principals", "command_receipts", "domain_events", "outbox_events"];
export async function startPostgresFixture() {
  const dir = await mkdtemp(join(tmpdir(), "rounds-v23-pg-"));
  const port = await new Promise<number>((resolve, reject) => {
    const server = createServer(); server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") throw new Error("No test port");
      server.close((error) => error ? reject(error) : resolve(address.port));
    });
  });
  const password = randomUUID();
  const cluster = new EmbeddedPostgres({ databaseDir: join(dir, "cluster"), port,
    user: "fixture_admin", password, persistent: true, createPostgresUser: false,
    authMethod: "scram-sha-256", postgresFlags: ["-h", "127.0.0.1", "-k", dir],
    initdbFlags: ["--encoding=UTF8", "--locale=C"], onLog: () => {}, onError: () => {} });
  let pool: pg.Pool | undefined; let admin: pg.Client | undefined;
  async function close() {
    try { await pool?.end(); } finally {
      try { await admin?.end(); } finally {
        await cluster.stop();
        // This exact directory was generated above; never uses a caller path.
        await rm(dir, { recursive: true, force: true });
      }
    }
  }
  try {
    await cluster.initialise(); await cluster.start();
    admin = cluster.getPgClient("postgres", "127.0.0.1"); await admin.connect();
    await admin.query("CREATE SCHEMA rounds; REVOKE ALL ON SCHEMA rounds FROM PUBLIC");
    const ddl = await readFile(new URL("ROUNDS-REVIEW-SCHEMA.sql", source), "utf8");
    for (const name of sourceTables) {
      const block = ddl.match(new RegExp(`CREATE TABLE rounds\\.${name} \\([\\s\\S]*?\\n\\);`))?.[0];
      if (!block) throw new Error(`Missing source table ${name}`);
      await admin.query(block);
      await admin.query(`ALTER TABLE rounds.${name} ENABLE ROW LEVEL SECURITY; ALTER TABLE rounds.${name} FORCE ROW LEVEL SECURITY`);
    }
    const policies = await readFile(new URL("ROLE-POLICIES.sql", source), "utf8");
    await admin.query("CREATE ROLE rounds_api NOLOGIN NOSUPERUSER NOBYPASSRLS; GRANT USAGE ON SCHEMA rounds TO rounds_api");
    for (const name of ["tenant", "principal", "city"]) {
      const fn = policies.split("\n").find((s) => s.startsWith(`CREATE OR REPLACE FUNCTION rounds.context_${name}()`));
      if (!fn) throw new Error("Missing source context function");
      await admin.query(fn);
    }
    for (const name of sourceTables.slice(2)) {
      const lines = policies.split("\n").filter((s) => (s.startsWith("CREATE POLICY ") || s.startsWith("GRANT ")) && s.includes(`ON rounds.${name} `) && s.includes("TO rounds_api"));
      if (lines.length !== 2) throw new Error(`Expected exact source grant/policy for ${name}`);
      await admin.query(lines.join("\n"));
    }
    // Exercise the forward policy migration against the old actor-only policy.
    await admin.query(`DROP POLICY account_scope ON rounds.command_receipts;
      CREATE POLICY account_scope ON rounds.command_receipts TO rounds_api
      USING (actor_id=rounds.context_principal()) WITH CHECK (actor_id=rounds.context_principal())`);
    await admin.query(await readFile(new URL("../../migrations/v23/0001-command-receipt-scope.sql", import.meta.url), "utf8"));
    // Synthetic probes, deliberately outside the product schema. Used to prove
    // the runner's rollback, locking and authorization callback contracts only.
    await admin.query(`CREATE SCHEMA v23_test; REVOKE ALL ON SCHEMA v23_test FROM PUBLIC;
      GRANT USAGE ON SCHEMA v23_test TO rounds_api;
      CREATE TABLE v23_test.access (tenant_id uuid, principal_id uuid, city_id uuid, allowed boolean NOT NULL DEFAULT true);
      CREATE TABLE v23_test.effects (id uuid PRIMARY KEY, tenant_id uuid NOT NULL, version integer NOT NULL DEFAULT 1);
      CREATE TABLE v23_test.deferred_effect (id uuid REFERENCES v23_test.effects(id) DEFERRABLE INITIALLY DEFERRED);
      GRANT SELECT ON v23_test.access TO rounds_api;
      GRANT SELECT, INSERT, UPDATE ON v23_test.effects, v23_test.deferred_effect TO rounds_api;
      ALTER TABLE v23_test.effects ENABLE ROW LEVEL SECURITY;
      ALTER TABLE v23_test.effects FORCE ROW LEVEL SECURITY;
      CREATE POLICY tenant_scope ON v23_test.effects TO rounds_api USING (tenant_id=rounds.context_tenant()) WITH CHECK (tenant_id=rounds.context_tenant());
      CREATE ROLE fixture_login LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS PASSWORD '${password}';
      GRANT rounds_api TO fixture_login`);
    const config = { host: "127.0.0.1", port, database: "postgres", user: "fixture_login", password, max: 2, connectionTimeoutMillis: 3000 };
    pool = new pg.Pool(config);
    return { pool, admin, close, config };
  } catch (error) { await close(); throw error; }
}
