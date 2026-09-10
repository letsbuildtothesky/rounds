"""Regenerate catalogue mirrors only; never replay earlier product decisions."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACTS = ROOT / 'specs/source/Rounds-Complete-Project-v2.3/specs/contracts'


def update(name, text):
    path = CONTRACTS / name
    if '--check' in sys.argv:
        assert path.read_text() == text, f'Regenerate command mirror: {name}'
    else:
        path.write_text(text)


commands = json.loads((CONTRACTS / 'COMMAND-CATALOG.json').read_text())
api = json.loads((CONTRACTS / 'openapi.json').read_text())
ops = {op['operationId']: op for methods in api['paths'].values()
       for op in methods.values() if isinstance(op, dict) and 'operationId' in op}
for command in commands:
    op = ops[command['name']]
    op['description'] = f"Capability: {command['capability']}. {command['transaction']} {command['version_rule']}"
    for key in ['errors', 'required_roots', 'emitted_events']:
        op['x-' + key.replace('_', '-')] = command[key]
update('openapi.json', json.dumps(api, indent=2, ensure_ascii=False) + '\n')
bindings = json.loads((CONTRACTS / 'ERROR-BINDINGS.json').read_text())
for binding in bindings:
    binding['commands'] = sorted(c['name'] for c in commands if binding['code'] in c['errors'])
update('ERROR-BINDINGS.json', json.dumps(bindings, indent=2, ensure_ascii=False) + '\n')
lines = ['# Command contracts — V2.3-r1', '', 'Generated from COMMAND-CATALOG and mirrored to OpenAPI. Ready does not mean implemented. See decisions/02 for engineering decisions and Build Spec DEC-01 for the gated workspace endpoint.', '']
for c in commands:
    lines += [f"## {c['name']}", '', f"Capability: `{c['capability']}`. Input: `{c['payload_schema']}`. Result: `{c['result_schema']}`.", '', c['fields'], '', c['transaction'], '', c['version_rule'], '', 'Roots: ' + json.dumps(c['required_roots']), '', 'Errors: ' + ', '.join(c['errors']), '', 'Fact outcomes: ' + ', '.join(c['emitted_events']), '']
update('COMMANDS.md', '\n'.join(lines))
transitions = json.loads((CONTRACTS / 'TRANSITIONS.json').read_text())
lines = ['# State transitions — V2.3-r1', '', 'Generated from TRANSITIONS.json. Historical-only and decision-blocked edges are NOT executable launch transitions.', '', '| ID | Domain | From | Command | To | Event | Availability | Guard |', '| --- | --- | --- | --- | --- | --- | --- | --- |']
for r in transitions:
    lines.append('| ' + ' | '.join([r['id'], r['domain'], ', '.join(r['from_states']) or 'create', r['command'], ', '.join(r['to_states']), r['event'] or 'none', r.get('availability', 'applicable release gate'), r['guard'].replace('|', '/')]) + ' |')
update('STATE-MACHINES.md', '\n'.join(lines) + '\n')
print('PASS catalogue mirrors' if '--check' in sys.argv else 'Generated catalogue mirrors')
