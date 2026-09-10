"""Render repository-grounded sections from the reviewed module register."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'specs/build-v2.3'


def main():
    register = json.loads((BUILD / 'MODULE-READINESS.json').read_text())
    baseline = register['baseline_commit']
    evidence = {}
    for module in register['modules']:
        for path in module['code'] + module['tests']:
            assert (ROOT / path).is_file(), path
            original = subprocess.run(['git', 'show', f'{baseline}:{path}'], cwd=ROOT, capture_output=True, check=True).stdout
            evidence[path] = {'baseline_commit': baseline, 'baseline_sha256': hashlib.sha256(original).hexdigest(),
                              'inspected_working_sha256': hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
                              'claim': 'code/reuse reference, not v2.3 acceptance evidence'}
    for module in register['modules']:
        path = BUILD / (module['id'] + '.md')
        text = path.read_text().split('\n## Repository implementation card')[0]
        text = re.sub(r'Version 0\.1 · 2026-09-08 · Review draft\.', 'Version 1.0 · 2026-09-08 · Active implementation contract; readiness is scoped below.', text)
        if '## Changelog' not in text:
            lines = text.splitlines()
            lines[4:4] = ['## Changelog', '', '- 1.0 (2026-09-08): reconcile v2.3-r1 rules, ground retain/adapt/replace work in baseline code, and separate implementation readiness from acceptance and release gates.', '']
            text = '\n'.join(lines) + '\n'
        text = text.replace('Resolve AUD-01/02/06 in source before generation.', 'AUD-01/02/06 are reconciled in v2.3-r1; enforce ADR-Q01 and the exact typed error contract.')
        text = text.replace('Reconcile AUD-03/04 before notification workers ship.', 'Use reconciled ADR-J01 for the notification identity and safe retry schedule.')
        text = text.replace('Registry defaults require the AUD-04 review;', 'Registry defaults are settled by ADR-J01;')
        text = text.replace('No deployed dependency is added in this documentation pass.', 'Pin dependencies within this repository before enabling the new runtime path.')
        text = text.replace('AUD-02/05/06 and schema/runtime gates must close before affected endpoints are enabled.', 'Reconciled contract assertions and schema/runtime gates must pass before endpoints are enabled; DEC-01 keeps only CreateTenant gated.')
        text = text.replace('R0 must pin the PostgreSQL client, schema/code generator, Node/Dart/SDK versions and pooling mode after verifying actual environments.', 'R0 must pin the PostgreSQL client, schema/code generator, Node/Dart/SDK versions and pooling mode after verifying actual environments; these are routine engineering decisions, not requests for product redesign.')
        body = ['## Repository implementation card', '', f"Baseline: `{baseline}`. Status: **{module['status']}** for **{module['scope']}**.", '',
                'Ready means sufficiently specified to implement the named scope. It does not claim existing code is compliant, tests passed or deployment approved.', '',
                '### Retain, adapt and replace', '', f"- Retain: {module['retain']}", f"- Adapt: {module['adapt']}", f"- Replace: {module['replace']}", '',
                'Relevant inspected code (per-file hashes in [repository evidence](generated/repository-evidence.json)):', '']
        body += [f'- [{p}](../../{p})' for p in module['code']]
        body += ['', '### Dependencies and compatibility', '', 'Dependencies: ' + '; '.join(module['dependencies']) + '.', '',
                 'Migration: ' + module['migration'], '', 'Offline/client compatibility: ' + module['offline'], '',
                 '### Acceptance and gates', '', module['acceptance'], '', 'Existing tests to retain/adapt; old passing status does not certify v2.3:', '']
        body += [f'- [{p}](../../{p})' for p in module['tests']]
        body += ['', 'Decision/deferred/enablement boundaries:', ''] + ['- ' + x for x in module['blocked']]
        body += ['', 'Follow [W01](FIRST-WORKFLOW.md), [decision/UI proposals](DECISIONS-AND-UI-GAPS.md) and [migration plan](MIGRATION-AND-REUSE.md).', '']
        path.write_text(text.rstrip() + '\n\n' + '\n'.join(body))
    (BUILD / 'generated/repository-evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
    lines = ['# Module readiness — v2.3-r1', '', 'Version 1.0 · 2026-09-08 · Rendered from MODULE-READINESS.json.', '',
             register['meaning'], '', 'One repository and one current spec set. Later phases remain in full-product scope; they are not secretly dropped.', '',
             '| Module | Status | Ready/deferred scope |', '| --- | --- | --- |']
    for m in register['modules']:
        lines.append(f"| [{m['id']}]({m['id']}.md) | {m['status']} | {m['scope']} |")
    lines += ['', '## Isolated blocked decisions', '',
              'See [DECISIONS-AND-UI-GAPS](DECISIONS-AND-UI-GAPS.md): CreateTenant admission, live policy/provider choices and genuinely absent UI variants are BLOCKED_BY_DECISION for their affected scope only. They do not block W01 using an existing configured tenant. R3/R4 and new Thai work are DEFERRED as described in the release plan.', '',
              '## First implementation', '', '[W01: own-team whole-order workflow](FIRST-WORKFLOW.md). The first code increment is the exact whole-order precondition gate and its source-derived metadata, not a claim of completed HTTP/DB/phone wiring.', '']
    (BUILD / 'READINESS.md').write_text('\n'.join(lines))
    print(f"Rendered {len(register['modules'])} module cards; verified {len(evidence)} unique baseline code/test files.")


if __name__ == '__main__':
    main()
