import assert from "node:assert/strict";
import { test } from "node:test";
import { createCommandPool } from "../../src/v23/command-pool.js";

test("command pool defaults to verified TLS and explicit private database identity", async () => {
  let errors = 0;
  const pool = createCommandPool({ databaseUrl: "postgresql://test:synthetic@private.invalid/rounds", onIdleConnectionFailure: () => { errors++; } });
  try {
    assert.deepEqual(pool.options.ssl, { rejectUnauthorized: true });
    assert.equal(pool.options.max, 4); assert.equal(pool.options.database, "rounds");
    pool.emit("error", new Error("synthetic sensitive error")); assert.equal(errors, 1);
    assert.equal(pool.totalCount, 0); // no connection or external database access
  } finally { await pool.end(); }
});
test("no implicit database, SSL override, missing secret or remote plaintext configuration", () => {
  for (const url of ["", "https://user:pass@private.invalid/db", "postgres://u:p@private.invalid", "postgres://u@private.invalid/db",
    "postgres://u:p@private.invalid/db?sslmode=disable", "postgres://u:p@private.invalid/db#fragment"]) {
    assert.throws(() => createCommandPool({ databaseUrl: url, onIdleConnectionFailure: () => {} }));
  }
  assert.throws(() => createCommandPool({ databaseUrl: "postgres://u:p@private.invalid/db", allowLocalPlaintext: true, onIdleConnectionFailure: () => {} }));
});
test("only explicitly selected loopback test connections can omit TLS", async () => {
  const pool = createCommandPool({ databaseUrl: "postgres://u:p@127.0.0.1:5432/synthetic", allowLocalPlaintext: true, onIdleConnectionFailure: () => {} });
  try { assert.equal(pool.options.ssl, false); assert.equal(pool.totalCount, 0); } finally { await pool.end(); }
});
