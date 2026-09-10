import { randomUUID } from "node:crypto";
import type { Client } from "pg";

/** Synthetic local orders in real product tables. No transport receipt or
 * physical custody is fabricated by planning/preparation fixtures.
 */
export async function seedWholeOrder(admin: Client, proofPolicy: unknown = {}) {
  const ids = Object.fromEntries(["tenant", "city", "otherCity", "actor", "membership", "grant", "driver", "site", "policy", "delivery", "manifest", "line", "unit", "round", "pickup", "dropoff", "assignment"].map(key => [key, randomUUID()])) as Record<string, string>;
  await admin.query("BEGIN");
  try {
    await admin.query("INSERT INTO rounds.tenants(id,name,country_code,default_timezone,default_currency,status) VALUES($1,'Isolated test tenant','TH','Asia/Bangkok','THB','active')", [ids.tenant]);
    await admin.query("INSERT INTO rounds.principals(id,display_name) VALUES($1,'Johannes test')", [ids.actor]);
    await admin.query("INSERT INTO rounds.cities(id,tenant_id,name,country_code,timezone) VALUES($1,$3,'Test city','TH','Asia/Bangkok'),($2,$3,'Other city','TH','Asia/Bangkok')", [ids.city, ids.otherCity, ids.tenant]);
    await admin.query("INSERT INTO rounds.memberships(id,tenant_id,principal_id,role_code,status) VALUES($1,$2,$3,'driver','active')", [ids.membership, ids.tenant, ids.actor]);
    await admin.query("INSERT INTO rounds.city_grants(id,tenant_id,membership_id,city_id,capabilities) VALUES($1,$2,$3,$4,ARRAY['driver.assigned_work'])", [ids.grant, ids.tenant, ids.membership, ids.city]);
    await admin.query("INSERT INTO rounds.drivers(id,principal_id,network_eligibility) VALUES($1,$2,'not_requested')", [ids.driver, ids.actor]);
    await admin.query("INSERT INTO rounds.driver_relationships(tenant_id,driver_id,relationship_kind,status) VALUES($1,$2,'team','active')", [ids.tenant, ids.driver]);
    await admin.query("INSERT INTO rounds.sites(id,tenant_id,city_id,name,site_type,address_text,timezone) VALUES($1,$2,$3,'Synthetic pickup','pickup','Test only','Asia/Bangkok')", [ids.site, ids.tenant, ids.city]);
    await admin.query("INSERT INTO rounds.policy_versions(id,tenant_id,policy_kind,scope_key,revision,schema_version,payload,effective_at,created_by) VALUES($1,$2,'proof','test',1,1,$4,now(),$3)", [ids.policy, ids.tenant, ids.actor, proofPolicy]);
    await admin.query(`INSERT INTO rounds.deliveries(id,tenant_id,city_id,pickup_site_id,human_reference,service_date,timezone,window_start_at,window_end_at,address_text,destination,readiness,outcome,evidence_state,proof_policy_id,created_by,preparation_state)
      VALUES($1,$2,$3,$4,'TEST-ONLY',current_date,'Asia/Bangkok',now(),now()+interval '1 hour','Synthetic destination',ST_GeogFromText('SRID=4326;POINT(100.5 13.7)'),'ready','open','none',$5,$6,'ready')`, [ids.delivery,ids.tenant,ids.city,ids.site,ids.policy,ids.actor]);
    await admin.query("INSERT INTO rounds.manifests(id,tenant_id,delivery_id,revision,source) VALUES($1,$2,$3,1,'manual')", [ids.manifest,ids.tenant,ids.delivery]);
    await admin.query("INSERT INTO rounds.manifest_lines(id,tenant_id,manifest_id,line_key,label,quantity,unit) VALUES($1,$2,$3,'L1','Synthetic items',5,'item')", [ids.line,ids.tenant,ids.manifest]);
    await admin.query("INSERT INTO rounds.fulfillment_units(id,tenant_id,delivery_id,manifest_id,state) VALUES($1,$2,$3,$4,'open')", [ids.unit,ids.tenant,ids.delivery,ids.manifest]);
    await admin.query("INSERT INTO rounds.fulfillment_unit_lines(tenant_id,unit_id,line_id,allocated_quantity) VALUES($1,$2,$3,5)", [ids.tenant,ids.unit,ids.line]);
    await admin.query("UPDATE rounds.deliveries SET current_manifest_id=$1 WHERE id=$2", [ids.manifest,ids.delivery]);
    await admin.query("INSERT INTO rounds.rounds(id,tenant_id,city_id,service_date,pickup_site_id,fulfillment_kind,driver_id,state,capacity_snapshot,policy_version_id,departure_gate) VALUES($1,$2,$3,current_date,$4,'team',$5,'released','{}',$6,'ready')", [ids.round,ids.tenant,ids.city,ids.site,ids.driver,ids.policy]);
    await admin.query("INSERT INTO rounds.stops(id,tenant_id,round_id,kind,sequence,destination_version,state,service_seconds) VALUES($1,$2,$3,'pickup',0,1,'arrived',60)", [ids.pickup,ids.tenant,ids.round]);
    await admin.query("INSERT INTO rounds.stops(id,tenant_id,round_id,delivery_id,kind,sequence,destination_version,state,service_seconds,fulfillment_unit_id) VALUES($1,$2,$3,$4,'dropoff',1,1,'released',60,$5)", [ids.dropoff,ids.tenant,ids.round,ids.delivery,ids.unit]);
    await admin.query("INSERT INTO rounds.assignments(id,tenant_id,round_id,driver_id,state,issued_at) VALUES($1,$2,$3,$4,'acknowledged',now())", [ids.assignment,ids.tenant,ids.round,ids.driver]);
    await admin.query("COMMIT");
    return ids;
  } catch (error) { await admin.query("ROLLBACK"); throw error; }
}
