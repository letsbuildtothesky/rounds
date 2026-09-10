"""Executable arithmetic/identity examples of the written rules, NOT application tests."""
import hashlib,json
from pathlib import Path
p=Path(__file__).resolve().parents[1];s=json.loads((p/'contracts/openapi.json').read_text())['components']['schemas'];tr=json.loads((p/'contracts/TRANSITIONS.json').read_text())
def report(n):print('PASS reference example',n)
# J01: custody quantities and replay identity; no network or API implementation is simulated as proof.
seen={};balance=0
def collect(command,quantity):
 global balance
 if command in seen:
  assert seen[command]==quantity
  return balance
 seen[command]=quantity;balance+=quantity;return balance
assert collect('C1',1)==1 and collect('C1',1)==1;report('J01 same physical command contributes quantity once')
# J02: the schema graph must actually provide the execution roots acceptance promises.
for family,state in [('assignments.state','acknowledged'),('rounds.state','released'),('stops.state','released')]:assert any(r['command']=='RespondOffer' and r['domain']==family and state in r['to_states'] for r in tr)
assert 'assignment_id' in s['OfferResponseResult']['properties'];report('J02 acceptance defines assignment and released execution roots')
# J03: full-order readiness; other orders remain independent.
required={'D1':5,'D2':2};ready={'D1':3,'D2':2}
assert ready['D1'] != required['D1'] and ready['D2']==required['D2']
assert s['ConfirmPickupPayload']['properties']['approval_decision_id']=={'type':'null','description':'Compatibility field; omit or null. Partial pickup approval is not supported at launch.'}
assert s['PickupResultData']['properties']['remaining_units']['maxItems']==0
sql=(p/'database/V23-COMPLETE-ORDER.sql').read_text();assert 'UNIQUE(tenant_id,delivery_id)' in sql and 'parent_unit_id IS NULL' in sql
ready['D1']=5;assert ready['D1']==required['D1'];report('J03 incomplete order blocks; other complete order can proceed; split allocation prohibited')
# J04: frozen successor request derives only from confirmed predecessor IDs, preserving assignment version.
observation={'observation_id':'O3','assignment_id':'A1','assignment_version':7,'dependency':'O1'};receipt={'attempt_id':'AT1','attempt_version':2}
request={'command_id':'C3','fence':{'assignment_id':observation['assignment_id'],'assignment_version':7},'payload':{'attempt_id':receipt['attempt_id']},'expected_attempt_version':2}
frozen=json.dumps(request,sort_keys=True);digest=hashlib.sha256(frozen.encode()).hexdigest();assert hashlib.sha256(frozen.encode()).hexdigest()==digest
current_assignment_version=8;assert request['fence']['assignment_version']!=current_assignment_version;assert request['payload']['attempt_id']=='AT1';report('J04 identity binding leaves original assignment fence intact on reassignment')
# J05: payment and earning dimensions are independent.
guaranteed=1000;earned=0;paid=400;assert max(earned-paid,0)==0
earned=1000;assert max(earned-paid,0)==600
paid+=600;adjustment=-100;final_entitlement=guaranteed+adjustment;assert max(paid-final_entitlement,0)==100
paid-=100;assert paid==900 and max(paid-final_entitlement,0)==0
assert s['RecordSettlementPayload']['properties'].get('state') is None;report('J05 prepayment, later earnings, adjustment and refund remain separate facts')
# J06: receipt readiness is computed per route, not by whole-truck completion.
received={'D1','D2','D4','D5'};r1={'D1','D2','D3'};r2={'D4','D5'};assert not r1<=received and r2<=received
received.add('D3');assert r1<=received;assert all(r['command']=='derive:departure_gate' for r in tr if r['domain']=='rounds.departure_gate' and r['from_states']);report('J06 independent receipt gates and synchronous gate ownership')
print('LIMIT: These are reference-rule examples, not API, concurrency, database, Flutter or device execution.')
