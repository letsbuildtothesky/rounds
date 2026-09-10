/** Full reference schema on a new local cluster, never a caller-supplied database.
 * ROUNDS_TEST_PG_BIN must point to PostgreSQL 17 binaries with PostGIS installed.
 * No application service, shared Supabase database or device data is touched.
 */
import { execFile } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { isAbsolute, join } from "node:path";
import { promisify } from "node:util";
import pg from "pg";

const exec = promisify(execFile);
const source = new URL("../../../../specs/source/Rounds-Complete-Project-v2.3/specs/database/", import.meta.url);
export const schemaStages = ["ROUNDS-REVIEW-SCHEMA.sql", "V22-INVARIANTS.sql", "V23-COMPLETE-ORDER.sql", "ROLE-POLICIES.sql", "V22-ROLE-POLICIES.sql"] as const;

export async function startPostgisFixture(options:{beforeProofMigration?:(admin:pg.Client)=>Promise<void>;beforeIssueMigration?:(admin:pg.Client)=>Promise<void>;beforePickupPhotoMigration?:(admin:pg.Client)=>Promise<void>;beforeDecisionMigration?:(admin:pg.Client)=>Promise<void>;beforeIntakeMigration?:(admin:pg.Client)=>Promise<void>}={}) {
  const bin = process.env.ROUNDS_TEST_PG_BIN;
  if (!bin || !isAbsolute(bin)) throw new Error("ROUNDS_TEST_PG_BIN must be an absolute PostgreSQL 17 bin directory with PostGIS; full database tests were NOT run");
  const { stdout: version } = await exec(join(bin, "postgres"), ["--version"]);
  if (!/PostgreSQL\) 17\./.test(version)) throw new Error("Full schema fixture requires PostgreSQL 17");
  const dir = await mkdtemp(join(tmpdir(), "rounds-v23-postgis-"));
  const cluster = join(dir, "cluster");
  const passwordFile = join(dir, "password");
  const password = randomUUID();
  let started = false; let admin: pg.Client | undefined; let pool: pg.Pool | undefined;
  const run = (program: string, args: string[]) => exec(join(bin, program), args, { timeout: 45000, maxBuffer: 1024 * 1024 });
  async function close() {
    try { await pool?.end(); } finally {
      try { await admin?.end(); } finally {
        if (started) await run("pg_ctl", ["-D", cluster, "-m", "fast", "-w", "stop"]);
        // Only this exact mkdtemp-created cluster is removed, after shutdown.
        await rm(dir, { recursive: true, force: true });
      }
    }
  }
  try {
    await writeFile(passwordFile, password, { mode: 0o600 });
    await run("initdb", ["-D", cluster, "-U", "fixture_admin", "--pwfile", passwordFile, "--auth=scram-sha-256", "--encoding=UTF8", "--locale=C"]);
    await rm(passwordFile);
    const port = await new Promise<number>((resolve, reject) => {
      const listener = createServer(); listener.on("error", reject);
      listener.listen(0, "127.0.0.1", () => {
        const address = listener.address();
        if (!address || typeof address === "string") return reject(new Error("No test port"));
        listener.close(error => error ? reject(error) : resolve(address.port));
      });
    });
    await run("pg_ctl", ["-D", cluster, "-l", join(dir, "postgres.log"), "-o", `-h 127.0.0.1 -p ${port} -k ${dir}`, "-w", "start"]);
    started = true;
    const config = { host: "127.0.0.1", port, database: "postgres", user: "fixture_admin", password, connectionTimeoutMillis: 3000 };
    admin = new pg.Client(config); await admin.connect();
    const hashes: Record<string, string> = {};
    for (const stage of schemaStages) {
      const sql = await readFile(new URL(stage, source), "utf8");
      hashes[stage] = createHash("sha256").update(sql).digest("hex");
      try { await admin.query(sql); }
      catch (error) { throw new Error(`Full schema stage ${stage} failed: ${error instanceof Error ? error.message : "database error"}`, { cause: error }); }
    }
    const authMigration = await readFile(new URL('../../migrations/v23/0002-api-auth-and-job-scope.sql',import.meta.url),'utf8');
    hashes['0002-api-auth-and-job-scope.sql'] = createHash('sha256').update(authMigration).digest('hex');
    await admin.query(authMigration);
    const deviceMigration = await readFile(new URL('../../migrations/v23/0003-device-installation-guard.sql',import.meta.url),'utf8');
    hashes['0003-device-installation-guard.sql'] = createHash('sha256').update(deviceMigration).digest('hex');
    await admin.query(deviceMigration);
    const assetMigration = await readFile(new URL('../../migrations/v23/0004-pod-asset-binding.sql',import.meta.url),'utf8');
    hashes['0004-pod-asset-binding.sql'] = createHash('sha256').update(assetMigration).digest('hex');
    await admin.query(assetMigration);
    await options.beforeProofMigration?.(admin);
    const proofMigration = await readFile(new URL('../../migrations/v23/0005-proof-evidence.sql',import.meta.url),'utf8');
    hashes['0005-proof-evidence.sql'] = createHash('sha256').update(proofMigration).digest('hex');
    await admin.query(proofMigration);
    await options.beforeIssueMigration?.(admin);
    const issueMigration = await readFile(new URL('../../migrations/v23/0006-issue-report-observation.sql', import.meta.url), 'utf8');
    hashes['0006-issue-report-observation.sql'] = createHash('sha256').update(issueMigration).digest('hex');
    await admin.query(issueMigration);
    await options.beforePickupPhotoMigration?.(admin);
    const pickupPhotoMigration = await readFile(new URL('../../migrations/v23/0007-pickup-issue-asset-binding.sql', import.meta.url), 'utf8');
    hashes['0007-pickup-issue-asset-binding.sql'] = createHash('sha256').update(pickupPhotoMigration).digest('hex');
    await admin.query(pickupPhotoMigration);
    await options.beforeDecisionMigration?.(admin);
    const decisionMigration = await readFile(new URL('../../migrations/v23/0008-issue-decision-reason.sql', import.meta.url), 'utf8');
    hashes['0008-issue-decision-reason.sql'] = createHash('sha256').update(decisionMigration).digest('hex');
    await admin.query(decisionMigration);
    await options.beforeIntakeMigration?.(admin);
    const intakeMigration = await readFile(new URL('../../migrations/v23/0009-manual-intake-revisions.sql', import.meta.url), 'utf8');
    hashes['0009-manual-intake-revisions.sql'] = createHash('sha256').update(intakeMigration).digest('hex');
    await admin.query(intakeMigration);
    const addressMigration = await readFile(new URL('../../migrations/v23/0010-intake-address-reviews.sql', import.meta.url), 'utf8');
    hashes['0010-intake-address-reviews.sql'] = createHash('sha256').update(addressMigration).digest('hex');
    await admin.query(addressMigration);
    await admin.query(`CREATE ROLE fixture_login LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS PASSWORD '${password}'; GRANT rounds_api TO fixture_login`);
    pool = new pg.Pool({ ...config, user: "fixture_login", max: 4 });
    const extensions = await admin.query("SELECT extname,extversion FROM pg_extension ORDER BY extname");
    return { admin, pool, close, evidence: { postgres: version.trim(), extensions: extensions.rows, sourceHashes: hashes } };
  } catch (error) { await close(); throw error; }
}
