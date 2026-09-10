"""Reproducible, local-only v2.3 source/build-plan audit. Never executes HTML.

Writes generated documentation only. Does not connect to a database/provider,
run application code, or classify existing screens as v2.3-complete.
"""
from pathlib import Path
from html.parser import HTMLParser
from collections import Counter
import csv
import hashlib
import json
import re
import sqlite3
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "specs/source/Rounds-Complete-Project-v2.3"
SPEC = SOURCE / "specs"
OUT = ROOT / "specs/build-v2.3/generated"
OWNERS = {
    "P01": ("BS-01", "R1", "identity"),
    "P02": ("BS-02", "R1", "intake"),
    "P03": ("BS-02", "R1", "calendars"),
    "P04": ("BS-03", "R1-core/R2-depth", "planning"),
    "P05": ("BS-04", "R1-core/R2-depth", "execution"),
    "P06": ("BS-06", "R1-team/R3-network", "drivers"),
    "P07": ("BS-10", "R3", "network"),
    "P08": ("BS-11", "R4-optional", "intercity"),
    "P09": ("BS-07", "R1-core/R2-depth", "communications"),
    "P10": ("BS-08", "R0/R1-core/R2-depth", "maps"),
    "P11": ("BS-09", "R1-core/R2-depth", "history"),
    "P12": ("BS-09", "R1-pilot/R2-adapters", "integrations"),
    "P13": ("BS-01", "R1-core/R2-depth", "configuration"),
    "P14": ("BS-12", "English-before-Thai", "ui"),
    "P15": ("BS-10", "R3", "ledger"),
    "E01": ("BS-00", "R0", "platform"),
    "E02": ("BS-00", "R0", "database"),
    "E03": ("BS-00", "R0", "contracts"),
    "E04": ("BS-00", "R0", "transactions"),
    "E05": ("BS-05", "R1", "offline"),
    "E06": ("BS-08", "R0/R1", "telemetry"),
    "E07": ("BS-07", "R1/R2", "workers"),
    "E08": ("BS-13", "all", "security"),
    "E09": ("BS-13", "all", "release"),
    "E10": ("BS-08", "provider-gated", "providers"),
}


def load(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def rel(path):
    return str(path.relative_to(ROOT))


class Controls(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.controls = []
        self.active = []
        self.ids = []
        self.scripts = []
        self.script = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id"):
            self.ids.append(a["id"])
        if tag == "script":
            self.script = {"attributes": a, "text": "", "line": self.getpos()[0]}
        clickable = tag in {"button", "input", "select", "textarea", "a"} or a.get("role") in {"button", "tab", "menuitem", "switch"} or "onclick" in a
        if clickable:
            item = {"tag": tag, "line": self.getpos()[0], "id": a.get("id"),
                    "label": a.get("aria-label") or a.get("title") or a.get("placeholder"),
                    "text": "", "handler": a.get("onclick"), "role": a.get("role"),
                    "disabled_in_source": "disabled" in a,
                    "binding_status": "STATIC_REFERENCE_ONLY; runtime binding and state variants require BS-12 evidence"}
            self.controls.append(item)
            if tag not in {"input"}:
                self.active.append((tag, item))

    def handle_data(self, text):
        if self.script is not None:
            self.script["text"] += text
        for _, item in self.active:
            item["text"] += text

    def handle_endtag(self, tag):
        if tag == "script" and self.script is not None:
            self.scripts.append(self.script)
            self.script = None
        for i in range(len(self.active) - 1, -1, -1):
            if self.active[i][0] == tag:
                self.active.pop(i)
                break


# Candidate files are reuse leads only, not a statement of runtime coverage.
DRIVER_CANDIDATES = {
    "A01": "driver_splash_screen.dart", "A01B": "language_screen.dart",
    "A02": "driver_entry_flow_screen.dart", "B00": "start_shift_screen.dart",
    "B01": "team_home_screen.dart", "B01B": "assigned_round_screen.dart",
    "B01C": "shift_end_screen.dart", "B01D": "team_home_screen.dart",
    "B01E": "team_home_screen.dart", "B01F": "shift_end_screen.dart",
    "D01": "pickup_navigation_screen.dart", "D03": "pickup_confirmation_screen.dart",
    "E01": "assigned_round_screen.dart", "E02": "navigation_harness_screen.dart",
    "E04": "live_delivery_change_screen.dart", "F01": "dropoff_handoff_screen.dart",
    "F03": "proof_of_delivery_screen.dart", "F08": "post_delivery_screen.dart",
    "G01": "recipient_unavailable_screen.dart", "G02": "location_problem_screen.dart",
    "G03": "delivery_package_problem_screen.dart", "G04": "cannot_complete_delivery_screen.dart",
    "G05": "driver_emergency_screen.dart", "H01": "operations_chat_screen.dart",
    "H02": "call_contact_screen.dart", "H03": "contact_history_screen.dart",
    "I01": "post_delivery_screen.dart", "J01": "my_rounds_screen.dart",
    "L01": "driver_profile_screen.dart",
    "N01": "driver_permissions_screen.dart",
    "N02": "offline_reconnecting_screen.dart",
    "N03": "gps_unavailable_screen.dart",
}


def screen_owner(code):
    if code[0] in "ABC" or code in {"K00", "L01", "N01"}:
        return "P07" if code.startswith("C") else "P06"
    if code in {"D01", "E02", "N03"}:
        return "P10"
    if code in {"E01", "E04"}:
        return "P04"
    if code[0] in "DFGI":
        return "P05"
    return {"H": "P09", "J": "P11", "K": "P15", "M": "P09", "N": "E05"}[code[0]]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    before = {rel(f): sha(f) for f in SOURCE.rglob("*") if f.is_file()}
    api = load(SPEC / "contracts/openapi.json")
    commands = load(SPEC / "contracts/COMMAND-CATALOG.json")
    tables = load(SPEC / "database/TABLE-CATALOG.json")
    transitions = load(SPEC / "contracts/TRANSITIONS.json")
    events = load(SPEC / "contracts/EVENT-CATALOG.json")
    services = load(SPEC / "contracts/SERVICE-ACTIONS.json")
    readiness = {x["id"]: x for x in load(ROOT / "specs/build-v2.3/MODULE-READINESS.json")["modules"]}
    features = list(csv.DictReader((SPEC / "review/FEATURE-TRACEABILITY.csv").open()))
    acceptance = list(csv.DictReader((SPEC / "review/ACCEPTANCE-REGISTER.csv").open()))
    operations = {op["operationId"]: (path, method, op) for path, methods in api["paths"].items() for method, op in methods.items() if isinstance(op, dict) and "operationId" in op}
    for f in SPEC.rglob("*.json"):
        load(f)
    for c in commands:
        assert c["name"] in operations
        assert c["payload_contract"] == api["components"]["schemas"][c["payload_schema"]]
        assert c["errors"] == operations[c["name"]][2]["x-errors"]
        assert c["required_roots"] == operations[c["name"]][2]["x-required-roots"]
        assert c["emitted_events"] == operations[c["name"]][2]["x-emitted-events"]
        bs, release, module = OWNERS[c["owner"]]
        if c["name"] == "ApprovePartialPickup":
            release = "DISABLED_ALL_LAUNCH_RELEASES"
        elif c["name"] == "RetainOfflineObservations":
            bs, module = "BS-05", "offline"
        status = readiness[bs]["status"]
        if c["name"] == "CreateTenant":
            status = "BLOCKED_BY_DECISION_DEC-01"
        elif c["name"] == "ApprovePartialPickup":
            status = "DEFERRED_DISABLED_AT_LAUNCH"
        c["build_plan"] = {"spec": bs + ".md", "release": release,
            "proposed_handler": f"services/api/src/v23/{module}/{c['name']}.ts",
            "implementation": "NOT_CERTIFIED_V23", "acceptance_run": None,
            "module_scope_readiness": status,
            "action_gates": "Module readiness applies only to its named scope; check BS card and DECISIONS-AND-UI-GAPS before enabling this individual action.",
            "source_conflicts": "../AUDIT.md (current resolved and isolated dispositions)"}
    write("commands.json", commands)
    queries = [{"name": name, "method": method, "path": path, "definition": op,
                "implementation": "NOT_CERTIFIED_V23", "build_spec": "BS-00.md; domain owner per BS-INDEX.md"}
               for name, (path, method, op) in operations.items() if "/commands/" not in path]
    write("queries-and-ingress.json", queries)
    for collection in [features, acceptance]:
        for row in collection:
            owner = Path(row["spec"]).name[:3]
            bs, release, _ = OWNERS[owner]
            row["build_spec"] = bs + ".md"
            row["build_release"] = release
            row["application_evidence"] = "NOT_RUN_V23"
    write("features.json", features)
    write("acceptance.json", acceptance)
    write("tables.json", [{**x, "build_spec": OWNERS[x["owner"]][0] + ".md"} for x in tables])
    write("service-actions.json", services)
    write("transition-event-index.json", {"transitions": transitions, "events": events,
        "consumers": load(SPEC / "contracts/EVENT-CONSUMERS.json"), "status": "source indexed; handler behavior NOT certified"})
    screen_files = sorted((SOURCE / "ui/driver/screens").glob("*.html"))
    ui, controls, script_checks = [], {}, []
    for f in [SOURCE / "ui/dispatch/index.html", *screen_files]:
        parser = Controls()
        parser.feed(f.read_text())
        for c in parser.controls:
            c["text"] = " ".join(c["text"].split())[:180]
        controls[rel(f)] = parser.controls
        for i, script in enumerate(parser.scripts):
            kind = script["attributes"].get("type", "")
            if kind not in {"", "text/javascript", "application/javascript", "module"} or "src" in script["attributes"]:
                continue
            result = subprocess.run(["node", "--check", "--input-type=" + ("module" if kind == "module" else "commonjs")],
                input=script["text"], text=True, capture_output=True)
            script_checks.append({"file": rel(f), "script_index": i, "line": script["line"], "syntax_ok": result.returncode == 0,
                                  "error": result.stderr[:400] if result.returncode else None})
        if f in screen_files:
            code = f.name.split("-")[1]
            owner = screen_owner(code)
            bs, release, _ = OWNERS[owner]
            matches = sorted((ROOT / "apps/driver_harness/lib/src").rglob(DRIVER_CANDIDATES[code])) if code in DRIVER_CANDIDATES else []
            candidate = matches[0] if len(matches) == 1 else None
            ui.append({"id": code, "filename": f.name, "source": rel(f), "sha256": sha(f),
                "build_specs": [bs + ".md", "BS-12.md"], "release": release,
                "candidate_code": rel(candidate) if candidate and candidate.exists() else None,
                "candidate_meaning": "reuse lead only; absence does not prove behavior absent elsewhere",
                "controls_in_static_markup": len(parser.controls),
                "design_refresh": "ORIGINAL_GROUP_REMAINS" if code in {"A02", "E04"} else "REFRESHED_PER_SOURCE_TRACKER",
                "visual_parity": "NOT_RENDERED", "functional_parity": "NOT_RUN",
                "state_expansion": "BS-12 requires all script-generated/sheet/error variants; static counts are not complete states"})
    write("driver-screens.json", ui)
    checklist = ["# Driver reference checklist — all 47 files", "",
        "Generated from unchanged approved v2.3 UI, alongside reconciled v2.3-r1 specs. A file can contain several screens/states.", "",
        "Every row still requires v2.3 functional and screenshot acceptance. A code candidate is only a reuse lead, not a built-screen count.", "",
        "| Reference | Build owners | Design refresh | Existing-code lead | Acceptance |",
        "| --- | --- | --- | --- | --- |"]
    for row in ui:
        source_link = "../../../" + row["source"]
        owners = ", ".join(f"[{Path(x).stem}](../{x})" for x in row["build_specs"])
        candidate_link = f"[Inspect](../../../{row['candidate_code']})" if row["candidate_code"] else "Not mapped; inspect before classifying"
        refresh = "Original combined group remains" if row["design_refresh"] == "ORIGINAL_GROUP_REMAINS" else "Refreshed in source"
        checklist.append(f"| [{row['filename']}]({source_link}) | {owners} | {refresh} | {candidate_link} | NOT RUN / NOT RENDERED |")
    (OUT / "DRIVER-CHECKLIST.md").write_text("\n".join(checklist) + "\n")
    write("ui-controls-static.json", controls)
    write("javascript-syntax.json", script_checks)
    # All JSON references are internal; resolve without fetching network resources.
    def refs(value, root):
        if isinstance(value, dict):
            if "$ref" in value:
                assert value["$ref"].startswith("#/"), value["$ref"]
                cursor = root
                for part in value["$ref"][2:].split("/"):
                    cursor = cursor[part.replace("~1", "/").replace("~0", "~")]
            for v in value.values():
                refs(v, root)
        elif isinstance(value, list):
            for v in value:
                refs(v, root)
    for name in ["openapi.json", "events.json"]:
        data = load(SPEC / "contracts" / name)
        refs(data, data)
    db = sqlite3.connect(":memory:")
    db.executescript((SPEC / "database/DRIVER-LOCAL-SCHEMA.sql").read_text())
    integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
    local_tables = db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0]
    assert integrity == "ok" and local_tables == 14
    ids = {r["id"] for r in acceptance}
    assert len(ids) == len(acceptance)
    for row in features:
        assert set(filter(None, row["acceptance_ids"].split(";"))) <= ids
    for row in acceptance:
        assert row["id"] in (SPEC / row["spec"]).read_text()
    schemas = api["components"]["schemas"]
    assert schemas["ConfirmPickupPayload"]["properties"]["approval_decision_id"]["type"] == "null"
    assert schemas["PickupResultData"]["properties"]["remaining_units"]["maxItems"] == 0
    examples = subprocess.run(["python3", str(SPEC / "review/validate_journey_examples.py")], capture_output=True, text=True)
    assert examples.returncode == 0, examples.stderr
    (OUT / "reference-journeys.txt").write_text(examples.stdout)
    source_mismatch = []
    for line in (SOURCE / "PACKAGE-SHA256.txt").read_text().splitlines():
        if re.match(r"^[0-9a-f]{64}\s", line):
            digest, name = line.split(maxsplit=1)
            target = SOURCE / name.lstrip("*")
            if not target.is_file() or sha(target) != digest:
                source_mismatch.append(name)
    assert not source_mismatch, source_mismatch
    after = {rel(f): sha(f) for f in SOURCE.rglob("*") if f.is_file()}
    assert before == after
    # Redacted credential-shape inventory: values are never written or printed.
    credential_shapes = []
    for f in SOURCE.rglob("*"):
        if f.suffix not in {".html", ".json", ".md", ".js"}:
            continue
        text = f.read_text()
        for label, pattern in [("Google API key shape", r"AIza[0-9A-Za-z_-]{30,}"),
                               ("Mapbox public token shape", r"pk\.eyJ[A-Za-z0-9_.-]+"),
                               ("Mapbox secret token shape", r"sk\.eyJ[A-Za-z0-9_.-]+")]:
            n = len(re.findall(pattern, text))
            if n:
                credential_shapes.append({"file": rel(f), "kind": label, "occurrences": n, "action": "review restrictions/provenance before publishing source; not proof of a private secret"})
    write("credential-shapes-redacted.json", credential_shapes)
    write("source-lock.json", {"baseline_commit": "19d6c1e7dc570546026cfb41135fae74c6b4e23e",
        "archive_sha256": "d4eb74b39335d5a97bea9300da4f65612773220ffdadff6465a954b9efedc39e",
        "working_revision": "2.3-r1", "meaning": "Working hashes; original archive hashes are in ../original-source-lock.json",
        "files": before})
    run_path = OUT / "test-results.json"
    validator_status = "NOT_RUN at this working-source fingerprint"
    pg_foundation_status = "NOT_RUN at this working source/code fingerprint"
    postgis_status = "NOT_RUN at this working source/code fingerprint"
    if run_path.is_file():
        runs = load(run_path)
        if runs["source_files"] == before:
            check = next((c for c in runs["checks"] if c["name"] == "supplied-validator"), None)
            if check:
                validator_status = check["status"] + ": local structural/schema/examples/SQL parse only; see test-results.json"
            pg_check = next((c for c in runs["checks"] if c["name"] == "api-and-pg-foundation-tests"), None)
            code_current = all((ROOT / p).is_file() and sha(ROOT / p) == digest for p, digest in runs["code_and_tool_files"].items())
            if pg_check and code_current and (ROOT / pg_check["log"]).is_file() and sha(ROOT / pg_check["log"]) == pg_check["log_sha256"]:
                pg_foundation_status = pg_check["status"] + ": five source tables and selected RLS policies, synthetic auth/domain probes, native PG transaction races/rollback; see test-results.json"
            full_check = next((c for c in runs["checks"] if c["name"] == "full-postgis-schema-tests"), None)
            if full_check and code_current and (ROOT / full_check["log"]).is_file() and sha(ROOT / full_check["log"]) == full_check["log_sha256"]:
                postgis_status = full_check["status"] + ": all131tables/five source SQL files plus isolated identity/job-scope and device-installation migrations installed; guards/probes, actual first-local pickup, registration/refresh/revocation and HTTP/job-status tests. Auth provider mocked; no configured Supabase Auth, native storage/queue upgrade, phone or full workflow acceptance; see test-results.json"
    report = {"source_files": len(before), "product_specs": 15, "engineering_specs": 10,
        "commands": len(commands), "disabled_partial_command": 1,
        "queries": sum(x[1] == "get" for x in operations.values()),
        "non_command_ingress": sum(method != 'get' and '/commands/' not in path for path, method, _ in operations.values()),
        "tables": len(tables), "local_tables": local_tables, "state_families": len(load(SPEC / "contracts/STATE-CODES.json")),
        "transitions": len(transitions), "events": len(events), "service_actions": len(services),
        "features": len(features), "written_acceptance": len(acceptance), "driver_html_files": len(ui),
        "ui_static_controls": sum(map(len, controls.values())), "inline_scripts_checked": len(script_checks),
        "inline_syntax_failures": sum(not x["syntax_ok"] for x in script_checks),
        "source_manifest": "PASS", "source_unchanged_by_audit": True,
        "json_references_and_command_mirrors": "PASS", "sqlite_clean_integrity": integrity,
        "reference_journeys": "6 small reference examples passed; not application tests",
        "full_supplied_validator": validator_status,
        "postgres_foundation_subset": pg_foundation_status,
        "full_postgis_schema_targeted_tests": postgis_status,
        "all_business_handlers_and_role_permutations": "NOT_RUN", "browser_and_device": "NOT_RUN",
        "completion_claim": "Inventory/structural audit only; resolved and isolated dispositions are in AUDIT.md"}
    write("audit-summary.json", report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
