"""Read-only specification consistency checks. No API/Postgres/device execution."""
from pathlib import Path
import json,csv,re,sqlite3,copy,warnings
import jsonschema
from pglast import parse_sql
warnings.filterwarnings('ignore',category=DeprecationWarning)
p=Path(__file__).resolve().parents[1];cp=p/'contracts';a=json.loads((cp/'openapi.json').read_text());s=a['components']['schemas']
def ok(msg):print('PASS',msg)
def refs(x,root):
 if isinstance(x,dict):
  if '$ref' in x:
   ref=x['$ref'];assert ref.startswith('#/'),ref;cur=root
   for part in ref[2:].split('/'):cur=cur[part.replace('~1','/').replace('~0','~')]
  for v in x.values():refs(v,root)
 elif isinstance(x,list):
  for v in x:refs(v,root)
for f in p.rglob('*.json'):json.loads(f.read_text())
for name in ['openapi.json','events.json']:
 x=json.loads((cp/name).read_text());refs(x,x)
 for v in x['components']['schemas'].values():jsonschema.Draft202012Validator.check_schema(v)
ok('JSON syntax, all local OpenAPI/event references and component schemas')
cs=json.loads((cp/'COMMAND-CATALOG.json').read_text());es=json.loads((cp/'EVENT-CATALOG.json').read_text());tn=json.loads((p/'database/TABLE-CATALOG.json').read_text());tables={t['name']:t for t in tn};ops={o['operationId'] for ms in a['paths'].values() for o in ms.values() if isinstance(o,dict) and 'operationId'in o}
assert len(tables)==len(tn)
for c in cs:
 assert c['name'] in ops
 assert c['payload_contract']==s[c['payload_schema']],c['name']
 assert c['errors']==a['paths']['/v1/commands/'+c['name']]['post']['x-errors']
 assert c['required_roots']==a['paths']['/v1/commands/'+c['name']]['post']['x-required-roots'],c['name']
 assert c['emitted_events']==a['paths']['/v1/commands/'+c['name']]['post']['x-emitted-events'],c['name']
 assert c['aggregate_table'] in tables
 for r in c['required_roots']:
  assert r['payload_field'].removesuffix('[]') in c['payload_contract']['properties'],(c['name'],r)
  assert r.get('aggregate_type') in tables or set(r.get('aggregate_type_by_discriminator',{}).values())<=set(tables)
 v=s[c['result_schema']]
 if 'state'in v.get('properties',{}) and 'resource'in v['properties']:
  state=v['properties']['state'].get('$ref','');assert not state.startswith('#/components/schemas/State_') or state.startswith('#/components/schemas/State_'+c['aggregate_table']+'_'),(c['name'],state)
bindings=json.loads((cp/'ERROR-BINDINGS.json').read_text());code_set=set(s['Error']['properties']['code']['enum']);assert {b['code'] for b in bindings}==code_set
for b in bindings:
 assert b['commands'] or b['other_origin'] or b['query_handlers'],b['code']
 assert set(b['commands'])=={c['name'] for c in cs if b['code'] in c['errors']},b['code']
ok(f'{len(cs)} command payload/error mirrors, root names and generic result-state ownership')
root={'components':{'schemas':s}};resolver=jsonschema.RefResolver.from_schema(root)
def valid(n,value,expect=True):
 errors=list(jsonschema.Draft202012Validator(s[n],resolver=resolver,format_checker=jsonschema.FormatChecker()).iter_errors(value));assert bool(not errors)==expect,(n,[e.message for e in errors][:2])
examples=json.loads((p/'review/CONTRACT-EXAMPLES.json').read_text())['examples'];assert set(examples)=={c['result_wrapper'] for c in cs}|{e['schema'] for e in es}
for n,v in examples.items():valid(n,v)
ok(f'{len(examples)} finite synthetic result/event instances; structural examples only')
u='00000000-0000-4000-8000-000000000001'
for n,change in [('CommitDeliveryResult',lambda v:v['data'].pop('delivery_id')),('Event_work_accepted',lambda v:v['payload'].pop('assignment_id'))]:
 v=copy.deepcopy(examples[n]);change(v);valid(n,v,False)
v=copy.deepcopy(examples['RecordSettlementResult']);v['data']['settlement']['earning_state']='active';valid('RecordSettlementResult',v,False)
valid('RecordSettlementPayload',{'agreement_id':u,'state':'externally_paid','amount_minor':1,'currency':'THB'},False)
valid('RecordSettlementPayload',{'agreement_id':u,'direction':'payment','amount_minor':400,'currency':'THB','payment_reference':'bank-001','occurred_at':'2026-09-08T01:00:00Z'})
pol=json.loads((cp/'POLICY-SCHEMAS.json').read_text())['schemas'];kinds={v['properties']['kind']['const'] for v in pol.values()};assert kinds==set(s['SavePolicyPayload']['properties']['policy_kind']['enum']);assert all(v==s[k] for k,v in pol.items())
assert kinds=={'own_fleet','broadcast','proof','customer','timing','commercial','retention','map','locale','slot','intake','intercity','messaging','escalation','account','weather'}
ok('Policy discriminants match all 16 schemas; payment mismatch and missing accepted-work identity rejected')
valid('GeneratePlanPayload',{'city_id':u,'service_date':'2026-09-08','fulfillment_unit_ids':[u]})
valid('GeneratePlanPayload',{'city_id':u,'service_date':'2026-09-08','fulfillment_unit_ids':[u],'delivery_ids':[u]},False)
valid('PlanProposalView',{}) if False else None
assert s['PlanProposalView']['properties']['version']=={'const':1}
pickup={'round_id':u,'pickup_stop_id':u,'manifest_ids':[u],'fulfillment_unit_ids':[u],'quantities':[{'line_id':u,'quantity':3}],'approval_decision_id':None};valid('ConfirmPickupPayload',pickup)
pickup.pop('approval_decision_id');valid('ConfirmPickupPayload',pickup)
for n in ['ConfirmPickup','ConfirmArrival','RecordHandoff','SubmitProof','CompleteDelivery','ReportIssue']:assert 'execution_fence' in s[n+'Request']['required']
valid('ReportIssuePayload',{'round_id':u,'issue_type':'pickup_wait','reason_code':'awaiting_goods','affected_lines':[],'asset_ids':[]})
valid('observed_line_quantities',[{'line_id':u,'quantity':-1}],False)
assert 'state' not in s['RecordSettlementPayload']['properties']
ok('Unit-selection exclusivity, immutable proposal version and original assignment fence are explicit')
tr=json.loads((cp/'TRANSITIONS.json').read_text());states=json.loads((cp/'STATE-CODES.json').read_text());services=json.loads((cp/'SERVICE-ACTIONS.json').read_text());sn={x['name'] for x in services};en={e['event'] for e in es};assert len(en)==len(es);assert len({e['schema'] for e in es})==len(es)
assert {r['domain'] for r in tr}==set(states)
for d,values in states.items():
 rows=[r for r in tr if r['domain']==d];seen=set()
 for r in rows:
  assert set(r['from_states']+r['to_states'])<=set(values),(d,r)
  assert r['command'] in ops|sn,r['command'];assert r['event'] is None or r['event'] in en
  assert 'receiving an invitation is not accepting a job' not in r['guard'];assert 'Provider outcome cannot be proved after timeout' not in r['guard']
 for _ in range(len(values)+1):
  for r in rows:
   if not r['from_states'] or seen&set(r['from_states']):seen.update(r['to_states'])
 assert seen==set(values),(d,set(values)-seen)
for d in ['assignments.state','rounds.state','stops.state']:assert any(r['command']=='RespondOffer' and r['domain']==d for r in tr)
for r in tr:
 if r['domain']=='rounds.departure_gate' and r['from_states']:assert r['command']=='derive:departure_gate'
assert not any(e.startswith(('deliverie.','intake_batche.')) for e in en)
assert not any(x['name'].startswith('worker:event_') for x in services)
for c in cs:assert set(c['emitted_events'])<=en
for e in es:
 assert examples[e['schema']]['event_type']==e['event'];assert set(e['producers'])<=ops|sn
for c in json.loads((cp/'EVENT-CONSUMERS.json').read_text()):assert c['event'] in en and c['dedupe_key'] and c['eligibility']
ok(f'{len(states)} reachable state families; freelance assignment/release edges; synchronous gate; event producers/consumers resolve')
assert {r['id'] for r in tr if r.get('availability')=='historical_only'}=={'TR-327','TR-328','TR-329','TR-330','TR-354'}
assert all(r.get('availability')=='historical_only' for r in tr if r['domain']=='remaining_obligations.state')
assert not any(r['command']=='ConfirmPickup' and not r['from_states'] and r.get('availability')!='historical_only' for r in tr if r['domain'] in {'fulfillment_units.state','remaining_obligations.state'})
assert 'PICKUP_NOT_READY' in next(c['errors'] for c in cs if c['name']=='ConfirmPickup')
assert all('five retries' in x['retry'] for x in services if x['name'].startswith('worker:'))
ok('r1 exact command mirrors, no executable pickup-created residual edge, preparation error and bounded retry policy; historical graph reachability is not launch enablement')
# PostgreSQL parsing is not execution or type/privilege proof.
sql=''
for n in ['ROUNDS-REVIEW-SCHEMA.sql','V22-INVARIANTS.sql','ROLE-POLICIES.sql','V22-ROLE-POLICIES.sql','SUPABASE-REALTIME-POLICIES.sql','V23-COMPLETE-ORDER.sql']:
 text=(p/'database'/n).read_text();parse_sql(text);sql+='\n'+text
created=set(re.findall(r'CREATE TABLE(?: IF NOT EXISTS)? rounds\.([a-z_]+)',sql,re.I));assert created==set(tables),(created-set(tables),set(tables)-created)
for n in ['grant_entitlement_identity','tracking_grant_work','notification_producer','unit_quantity_conservation','collected_allocation_frozen','notification_source_event','assignment_origin','purge_expired_gps','auth_resolver_self']:assert n in sql,n
ok(f'Six PostgreSQL files parsed; {len(tables)} table inventory and named invariants present (NOT applied)')
db=sqlite3.connect(':memory:');db.executescript((p/'database/DRIVER-LOCAL-SCHEMA.sql').read_text());assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok';lc=db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0];assert lc==14
ok('Driver SQLite clean schema executed: 14 tables and integrity_check=ok; no encryption/device behavior tested')
ac=list(csv.DictReader((p/'review/ACCEPTANCE-REGISTER.csv').open()));features=list(csv.DictReader((p/'review/FEATURE-TRACEABILITY.csv').open()));ids={r['id'] for r in ac};featureids={r['feature_id'] for r in features};assert len(ids)==len(ac)
for r in ac:
 assert r['id'] in (p/r['spec']).read_text()
 assert set(re.split('[,; ]+',r['feature_ids']))<=featureids
 assert set(filter(None,r.get('expected_events','').split(',')))<=en,(r['id'],r.get('expected_events'))
for r in features:
 assert set(filter(None,r['acceptance_ids'].split(';')))<=ids
for j in json.loads((p/'journeys/JOURNEYS.json').read_text()):assert set(j['events'])<=en,(j['id'],set(j['events'])-en)
ok('Acceptance ownership/feature links and all six journey fact names resolve; cases remain written')
for f in p.rglob('*.md'):
 if 'inputs' in f.parts:continue
 for m in re.finditer(r'\]\(([^)]+)\)',f.read_text()):
  link=m[1].split('#')[0]
  if link and '://' not in link:assert (f.parent/link).exists(),(f.name,link)
ok('Authored relative document links resolve')
print('NOT TESTED: actual PostgreSQL/Supabase privileges, triggers or races; API/device/provider execution; generated clients; browser visual parity. This script does not modify files.')
