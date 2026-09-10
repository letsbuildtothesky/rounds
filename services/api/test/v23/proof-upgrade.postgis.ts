import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { startPostgisFixture } from './postgis-fixture.js';
import { seedWholeOrder } from './whole-order-fixture.js';
test('isolated pre-0005 proof rows survive nullable expansion without invented evidence', async (t) => {
    const attempt = randomUUID(), handoff = randomUUID(), submission = randomUUID(), item = randomUUID();
    let before: unknown, proofBefore: unknown;
    const db = await startPostgisFixture({ beforeProofMigration: async (admin) => {
            // Only this fresh disposable cluster: emulate the previous v2.3 field set.
            // Structural historical fixtures are NOT evidence of a real handoff.
            await admin.query('ALTER TABLE rounds.proof_items DROP COLUMN note, DROP COLUMN location_observation_id');
            const ids = await seedWholeOrder(admin);
            await admin.query(`INSERT INTO rounds.delivery_attempts(id,tenant_id,delivery_id,stop_id,driver_id,attempt_number,state,fulfillment_unit_id) VALUES($1,$2,$3,$4,$5,1,'handed_over',$6)`, [attempt, ids.tenant, ids.delivery, ids.dropoff, ids.driver, ids.unit]);
            await admin.query(`INSERT INTO rounds.handoffs(id,tenant_id,attempt_id,receiver_kind,occurred_at,actor_id,proof_policy_id,state) VALUES($1,$2,$3,'recipient',now(),$4,$5,'recorded')`, [handoff, ids.tenant, attempt, ids.actor, ids.policy]);
            await admin.query(`INSERT INTO rounds.proof_submissions(id,tenant_id,attempt_id,handoff_id,policy_version_id,submitted_by,state,command_id) VALUES($1,$2,$3,$4,$5,$6,'pending',$7)`, [submission, ids.tenant, attempt, handoff, ids.policy, ids.actor, randomUUID()]);
            await admin.query(`INSERT INTO rounds.proof_items(id,tenant_id,submission_id,item_kind,line_id,quantity,state,captured_at,received_at) VALUES($1,$2,$3,'manifest',$4,5,'pending',now(),now())`, [item, ids.tenant, submission, ids.line]);
            before = (await admin.query('SELECT to_jsonb(p) AS data FROM rounds.proof_items p WHERE id=$1', [item])).rows[0].data;
            proofBefore = (await admin.query('SELECT to_jsonb(p) AS data FROM rounds.proof_submissions p WHERE id=$1', [submission])).rows[0].data;
        } });
    t.after(() => db.close());
    const result = (await db.admin.query('SELECT to_jsonb(p) AS data FROM rounds.proof_items p WHERE id=$1', [item])).rows[0].data;
    assert.equal(result.note, null);
    assert.equal(result.location_observation_id, null);
    const { note, location_observation_id, ...old } = result;
    assert.deepEqual(old, before);
    assert.deepEqual((await db.admin.query('SELECT to_jsonb(p) AS data FROM rounds.proof_submissions p WHERE id=$1', [submission])).rows[0].data, proofBefore);
    assert.equal(result.state, 'pending');
    await assert.rejects(db.admin.query("UPDATE rounds.proof_items SET note='guessed' WHERE id=$1", [item]), /IMMUTABLE_RECORD/);
});
