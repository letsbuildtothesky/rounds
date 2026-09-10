"""One-time owning-contract reconciliation for ADR-Q02; no UI/schema migration."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
path = root / 'specs/source/Rounds-Complete-Project-v2.3/specs/contracts/openapi.json'
api = json.loads(path.read_text())
s = api['components']['schemas']
ref = lambda name: {'$ref': '#/components/schemas/' + name}
def obj(properties):
    return {'type': 'object', 'properties': properties, 'required': list(properties), 'additionalProperties': False}
def array(items, minimum=0):
    return {'type': 'array', 'items': items, 'minItems': minimum, 'maxItems': 1000}
s['DriverExecutionStopScope'] = obj({'stop_id': ref('uuid'), 'fulfillment_unit_ids': array(ref('uuid'), 1)})
s['DriverExecutionProofPolicy'] = obj({'fulfillment_unit_id': ref('uuid'), 'policy_version_id': ref('uuid'), 'policy': ref('ProofPolicy')})
s['DriverExecutionContext'] = obj({
    **{name: ref('uuid') for name in ['principal_id', 'tenant_id', 'city_id', 'round_id', 'assignment_id']},
    'assignment_version': ref('positive_integer'),
    'accepted_scope_hash': {'type': 'string', 'pattern': '^[0-9a-f]{64}$'},
    'stop_units': array(ref('DriverExecutionStopScope'), 1),
    'expected_versions': array(ref('expected_version'), 1),
    'proof_policies': array(ref('DriverExecutionProofPolicy'), 1),
    'fetched_at': {'type': 'string', 'format': 'date-time'},
})
s['DriverExecutionOrder'] = obj({
    **{name: ref('uuid') for name in ['delivery_id', 'fulfillment_unit_id', 'manifest_id', 'dropoff_stop_id']},
    'quantities': ref('line_quantities'),
    'preparation_state': ref('ready_state'),
})
s['DriverRoundExecutionProjection'] = obj({
    'view': {'const': 'execution'}, 'context': ref('DriverExecutionContext'),
    'pickup_stop_id': ref('uuid'), 'orders': array(ref('DriverExecutionOrder'), 1),
})
s['DriverRoundExecutionQueryResult'] = obj({
    'as_of': {'type': 'string', 'format': 'date-time'}, 'data': ref('DriverRoundExecutionProjection'), 'next_cursor': {'type': 'null'},
})
q = api['paths']['/v1/queries/DriverRound']['get']
q['parameters'] = [q['parameters'][0]] + [
    {'name': 'view', 'in': 'query', 'required': False, 'schema': {'type': 'string', 'enum': ['full', 'execution'], 'default': 'full'}},
    *[{'name': n, 'in': 'query', 'required': False, 'description': 'Required for execution view. Filter only; live authorization is mandatory.', 'schema': ref('uuid')} for n in ['tenant_id', 'city_id']],
]
q['responses']['200']['content']['application/json']['schema'] = {'oneOf': [ref('DriverRoundQueryResult'), ref('DriverRoundExecutionQueryResult')]}
for status in ['400', '401', '404', '422', '429', '503']:
    q['responses'][status] = {'description': 'Typed execution query rejection; no partial work projection.', 'content': {'application/json': {'schema': ref('Error')}}}
q['parameters'].append({'name': 'X-Rounds-Device-Session', 'in': 'header', 'required': False, 'description': 'Required for execution view; revocable ADR-A02 device capability.', 'schema': {'type': 'string', 'maxLength': 2048}})
q['description'] = 'Minimal authorized projection. ADR-Q02 adds explicit view=execution for acknowledged own-team local work, with tenant_id/city_id filters and a current device session. The default full view is unchanged and not implemented by the isolated execution increment. Execution view is a coherent bounded snapshot, not execution permission or a command receipt; no commercial acceptance or physical receipt is fabricated.'
path.write_text(json.dumps(api, indent=2) + '\n')
