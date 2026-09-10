"""Mechanical reconciliation of reviewed v2.3 corrections and contract mirrors.

Original source is retained in archives/Rounds-Complete-Project-v2.3.zip.
This edits the existing working spec tree, never the app/database/UI HTML.
R1-specific migration, not a general spec editor: review later product decisions
before rerunning; do not overwrite newer decisions with this checkpoint.
"""
from pathlib import Path
import csv
import hashlib
import io
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'specs/source/Rounds-Complete-Project-v2.3'
S = SOURCE / 'specs'


def read_json(name):
    return json.loads((S / name).read_text())


def save(name, text):
    path = S / name
    if path.read_text() != text:
        path.write_text(text)


def save_json(name, value):
    save(name, json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def replace(name, old, new):
    text = (S / name).read_text()
    if old not in text:
        assert new in text, (name, old)
        return
    save(name, text.replace(old, new))


def revision(name, explanation):
    text = (S / name).read_text()
    text = text.replace('Consolidated V2.3 ·', 'Consolidated V2.3-r1 ·')
    if text.startswith('# V2.3 '):
        text = text.replace('# V2.3 ', '# V2.3-r1 ', 1)
    marker = '## Reconciliation changelog'
    if marker not in text:
        title, rest = text.split('\n', 1)
        text = title + '\n\n' + marker + '\n\n- 2026-09-08 · v2.3-r1: ' + explanation + '\n' + rest
    save(name, text)


def main():
    replace('decisions/01-OPERATING-DECISIONS.md',
        'Splitting a partly received delivery needs an approved partial-pickup decision, preserved quantities and consent if accepted work changes.',
        'A partly received customer order cannot be split. Explicitly adjust the route/assignment to let independent complete orders proceed; accepted freelancer changes still require consent.')
    replace('decisions/01-OPERATING-DECISIONS.md',
        'A partial approval is the sole alternative for authorized subsets.',
        'No partial approval or operator override permits a short pickup. Independent complete orders may proceed after explicit route adjustment.')
    replace('engineering/E07-BACKGROUND-JOBS-ADAPTERS-AND-RECOVERY.md',
        '| Notifications/push | event/recipient/channel/template |',
        '| Notifications/push | event/recipient/channel/kind; freeze template snapshot on first intent |')
    retry = ('For safe transient failures, schedule at most five retries after the initial attempt: delays of 5, 30, 120, 600 and 1800 seconds, measured from the failed attempt. '
             'After the sixth failed attempt total, enter recovery. No random jitter in the default policy. Stop at the job deadline. '
             'Use max(schedule delay, valid Retry-After); if beyond deadline, expire/recover without sending. '
             'Permanent validation or revoked-authority failures require correction, not automatic retries. '
             'Unknown/provider-accepted effects reconcile the original identity and never follow the resend schedule. '
             'Synchronous derive/internal actions do not use worker retries. ADR-J01 owns this engineering default; tenant configuration cannot turn unknown effects into resendable work.')
    name = 'engineering/E07-BACKGROUND-JOBS-ADAPTERS-AND-RECOVERY.md'
    text = (S / name).read_text()
    start, end = text.index('## Retry classification'), text.index('## Adapter contracts')
    save(name, text[:start] + '## Retry classification\n\n' + retry + '\n\n' + text[end:])
    replace('decisions/03-DEFAULTS-AND-OPEN-GATES.md',
        '| Retry | 5s exponential+jitter;15min cap/12 attempts | Stop at job deadline; reconcile unknown effects | Review |',
        '| Retry | Five retry delays: 5/30/120/600/1800 seconds after the initial attempt | Deadline and Retry-After take precedence; unknown effects reconcile, never blind resend | Engineering decision ADR-J01 |')
    replace('engineering/E03-HTTP-API-AND-READ-PROJECTIONS.md', 'define 128 typed command endpoints', 'define 131 typed command endpoints (including the disabled partial-pickup command)')
    replace('engineering/E10-PROVIDER-DECISIONS-SOURCES-AND-OPEN-GATES.md',
        '| Server routing/geocoding | Adapter abstraction; exact provider unresolved |',
        '| Server routing/geocoding | Mapbox-derived Operations driving geometry selected by ADR-M01; geocoding adapter and unsupported vehicle profiles remain gated |')

    rules = read_json('contracts/DOMAIN-RULES.json')
    old_rules = dict(rules)
    rules['fulfillment_units.state'] = ('Exactly one internal unit contains every current manifest line of one customer delivery. No split, child, residual unit or independent portion assignment at launch. '
        'CommitDelivery creates that whole unit; ConfirmPickup only changes an existing open whole unit to collected after full line equality, preparation readiness and actual inbound availability. '
        'Collected allocation is frozen. Delivered requires complete actual handoff and verified required proof; returned/cancelled require actual custody disposition. Preserve original delivery identity.')
    rules['remaining_obligations.state'] = ('Historical split-work state family only, not executable launch work. No launch command creates or plans a pickup remainder. '
        'Legacy residual records require supervised migration/incident disposition and may not be converted into new independent delivery portions. '
        'Real damage, shortage and partial return/receipt observations remain truthful under issues/returns/custody, not split delivery execution.')
    # Authority is a genuine product choice; disabled until the owner responds.
    rules['tenants.status'] = ('CreateTenant is disabled pending the workspace-admission decision DEC-01; no actor may use it until the chosen authority is reconciled. '
        'SuspendTenant/CloseTenant/RestoreTenant require platform tenant administration. Suspension/closure stops new admissions but preserves accepted-work recovery and exports. '
        'Existing configured tenants remain usable; isolated test tenancy is separately provisioned by fixture credentials.')
    save_json('contracts/DOMAIN-RULES.json', rules)
    transitions = read_json('contracts/TRANSITIONS.json')
    for row in transitions:
        domain = row['domain']
        if domain in ['fulfillment_units.state', 'remaining_obligations.state', 'tenants.status']:
            row['guard'] = rules[domain] + f" Selected outcome {','.join(row['to_states'])} requires the exact {row['command']} payload branch, locked scope and versions."
        if domain == 'remaining_obligations.state' or row['id'] == 'TR-354':
            row['availability'] = 'historical_only'
            row['guard'] = 'DISABLED AT LAUNCH: historical transition retained for migration provenance; zero live domain writes. ' + row['guard']
        if row['command'] == 'CreateTenant':
            row['availability'] = 'blocked_by_decision_DEC-01'
    save_json('contracts/TRANSITIONS.json', transitions)
    commands = read_json('contracts/COMMAND-CATALOG.json')
    for c in commands:
        if c['name'] == 'CompleteDelivery':
            c['transaction'] = ('Lock the attempt, its single whole-delivery unit, manifest/custody and proof. Require actual handoff of every required manifest quantity and verified required proof for this attempt. '
                'Complete the whole unit and stop and release their claim atomically; no mixed delivered/cancelled portions may produce delivered. '
                'Independent complete orders may finish without unrelated orders. Round completion requires all its assigned orders, returns and evidence resolved. '
                'Earn only the accepted agreement scope; retain failed/short physical outcomes as issues/disposition, never a new remainder delivery.')
        if c['name'] == 'ConfirmPickup':
            c['transaction'] = rules['fulfillment_units.state'] + ' Validate the entire selected batch before any custody/attempt writes; no implicit skipping. Non-ready preparation returns PICKUP_NOT_READY; unequal full quantities return COMPLETE_ORDER_REQUIRED.'
            c['errors'] = sorted(set(c['errors']) | {'PICKUP_NOT_READY'})
        if c['name'] == 'CreateTenant':
            c['transaction'] = 'DEC-01 pending: endpoint disabled with FEATURE_NOT_ENABLED and no domain writes. Existing tenants continue working. Once authority is chosen, create owner membership/settings atomically and dedupe onboarding intent.'
            c['errors'] = sorted(set(c['errors']) | {'FEATURE_NOT_ENABLED'})
    save_json('contracts/COMMAND-CATALOG.json', commands)
    api = read_json('contracts/openapi.json')
    api['info']['version'] = '2.3-r1'
    ops = {op['operationId']: op for methods in api['paths'].values() for op in methods.values() if isinstance(op, dict) and 'operationId' in op}
    for c in commands:
        op = ops[c['name']]
        op['description'] = f"Capability: {c['capability']}. {c['transaction']} {c['version_rule']}"
        op['x-errors'] = c['errors']
        op['x-required-roots'] = c['required_roots']
        op['x-emitted-events'] = c['emitted_events']
    ops['CreateTenant']['x-release-scope'] = 'blocked_by_decision_DEC-01'
    save_json('contracts/openapi.json', api)
    bindings = read_json('contracts/ERROR-BINDINGS.json')
    for b in bindings:
        b['commands'] = sorted(c['name'] for c in commands if b['code'] in c['errors'])
    save_json('contracts/ERROR-BINDINGS.json', bindings)
    actions = read_json('contracts/SERVICE-ACTIONS.json')
    for action in actions:
        if action['name'].startswith('worker:'):
            action['retry'] = 'Lease 60s with heartbeat every 20s. ' + retry
    save_json('contracts/SERVICE-ACTIONS.json', actions)

    # Human-readable mirrors are derived, not independently maintained prose.
    lines = ['# Command contracts — V2.3-r1', '', 'Generated from COMMAND-CATALOG and mirrored to OpenAPI. Ready does not mean implemented. See decisions/02 for engineering decisions and Build Spec DEC-01 for the gated workspace endpoint.', '']
    for c in commands:
        lines += [f"## {c['name']}", '', f"Capability: `{c['capability']}`. Input: `{c['payload_schema']}`. Result: `{c['result_schema']}`.", '', c['fields'], '', c['transaction'], '', c['version_rule'], '', 'Roots: ' + json.dumps(c['required_roots']), '', 'Errors: ' + ', '.join(c['errors']), '', 'Fact outcomes: ' + ', '.join(c['emitted_events']), '']
    save('contracts/COMMANDS.md', '\n'.join(lines))
    lines = ['# State transitions — V2.3-r1', '', 'Generated from TRANSITIONS.json. Historical-only and decision-blocked edges are NOT executable launch transitions.', '', '| ID | Domain | From | Command | To | Event | Availability | Guard |', '| --- | --- | --- | --- | --- | --- | --- | --- |']
    for r in transitions:
        lines.append('| ' + ' | '.join([r['id'], r['domain'], ', '.join(r['from_states']) or 'create', r['command'], ', '.join(r['to_states']), r['event'] or 'none', r.get('availability', 'applicable release gate'), r['guard'].replace('|', '/')]) + ' |')
    save('contracts/STATE-MACHINES.md', '\n'.join(lines) + '\n')

    replacement_cases = {
        'QA-V21-PARTIAL-APPROVAL': (
            'D1 needs five, only three available; D2 is complete. Attempt partial D1 and an atomic D1+D2 pickup, then invoke approval. Explicitly adjust assignment to D2 only and retry with new identity; finally receive/prepare all five for D1.',
            'Short pickup and mixed batch reject COMPLETE_ORDER_REQUIRED or actual inbound readiness error with zero custody/attempt/residual writes. Approval returns FEATURE_NOT_ENABLED for every role. D2 succeeds only after explicit adjustment, with one whole unit. D1 succeeds only when all five are present and ready. Replay produces no extra balance or fact.'),
        'QA-V21-FULL-PICKUP': (
            'For a full actually present manifest, test preparation unknown/preparing/blocked and ready; omit approval_decision_id. Also send missing/extra/duplicate line IDs, short/excess quantities, duplicate selectors and decimal quantities with more than four places.',
            'Only ready plus exact line-map equality can commit; non-ready preparation returns PICKUP_NOT_READY. Invalid IDs/selectors/precision reject validation or manifest contract; unequal quantities return COMPLETE_ORDER_REQUIRED. Batch rejects before writes. No approval ID, child unit or remainder obligation is created. Exact four-place decimal quantities are compared as integer quanta.'),
        'QA-V21-NOTIFICATION-RETRY': (
            'Enqueue one event twice; change template from v1 to v2 and replay. Inject six safe transient failures, Retry-After beyond deadline and an unknown provider outcome.',
            'One intent per event/recipient/channel/kind retains template v1. Five retries after the initial attempt wait 5/30/120/600/1800 seconds; sixth total failure enters recovery. Deadline prevents further send. Unknown outcome reconciles original identity without automatic resend.'),
    }
    register_path = S / 'review/ACCEPTANCE-REGISTER.csv'
    rows = list(csv.DictReader(register_path.open(newline='')))
    for row in rows:
        if row['id'] not in replacement_cases:
            continue
        row['steps'], row['expected'] = replacement_cases[row['id']]
        path = S / row['spec']
        text = path.read_text()
        start = text.index('### ' + row['id'])
        end = text.find('\n### ', start + 1)
        end = len(text) if end < 0 else end
        body = f"### {row['id']}\n\nActor: {row['actor']}\n\nGiven: {row['fixture']}\n\nWhen: {row['steps']}\n\nThen: {row['expected']}\n\nStatus: written requirement; application execution pending.\n"
        save(row['spec'], text[:start] + body + text[end:])
    output = io.StringIO(newline='')
    writer = csv.DictWriter(output, fieldnames=list(rows[0]), lineterminator='\r\n')
    writer.writeheader(); writer.writerows(rows)
    register_path.write_bytes(output.getvalue().encode())
    for name, why in {
        'decisions/01-OPERATING-DECISIONS.md': 'Remove obsolete partial approval; preserve independent complete orders and pre-arrival planning.',
        'decisions/03-DEFAULTS-AND-OPEN-GATES.md': 'Choose explicit durable retry schedule as routine engineering decision ADR-J01.',
        'engineering/E07-BACKGROUND-JOBS-ADAPTERS-AND-RECOVERY.md': 'Align retry policy, notification identity and written failure cases.',
        'engineering/E03-HTTP-API-AND-READ-PROJECTIONS.md': 'Correct command inventory; all required-root mirrors reconciled by ADR-C01.',
        'engineering/E10-PROVIDER-DECISIONS-SOURCES-AND-OPEN-GATES.md': 'Preserve selected Mapbox direction while retaining actual provider/field gates.',
        'product/P05-EXECUTION-CUSTODY-PROOF-AND-EXCEPTIONS.md': 'Specify readiness/error, atomic whole-order validation and precise acceptance negatives.',
    }.items():
        revision(name, why)
    print('Reconciled current source sections, JSON/Markdown mirrors and three acceptance cases. No runtime/HTML/database changes.')


if __name__ == '__main__':
    main()
