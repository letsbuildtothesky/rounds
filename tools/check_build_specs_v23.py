"""Validate active spec links, provenance, repository cards and evidence freshness."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from urllib.parse import unquote
import zipfile
from source_reference_provenance import publishable_reference_bytes

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "specs/build-v2.3"
SOURCE = ROOT / "specs/source/Rounds-Complete-Project-v2.3"
GENERATED = BUILD / "generated"


def load(name):
    return json.loads((GENERATED / name).read_text())


def main():
    errors = []
    documents = sorted(BUILD.rglob("*.md")) + [
        ROOT / "README.md", ROOT / "AGENTS.md", ROOT / "CODEX-BUILD-ORDER.md",
        ROOT / "specs/build/BUILD-SPEC-INDEX.md",
    ]
    links = 0
    for document in documents:
        for match in re.finditer(r"\[[^\]\n]+\]\(([^)\n]+)\)", document.read_text()):
            target = match.group(1).strip().strip("<>")
            if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
                continue
            target = unquote(target.split("#")[0])
            links += 1
            if not (document.parent / target).exists():
                errors.append(f"Missing link: {document.relative_to(ROOT)} -> {target}")
    for i in range(14):
        if not (BUILD / f"BS-{i:02}.md").is_file():
            errors.append(f"Missing BS-{i:02}")
    registers = [("commands.json", 131), ("features.json", 150),
                 ("acceptance.json", 197), ("tables.json", 131), ("driver-screens.json", 47)]
    for name, count in registers:
        rows = load(name)
        if len(rows) != count:
            errors.append(f"Unexpected register size: {name}={len(rows)}")
        for row in rows:
            owners = row.get("build_specs") or [row.get("build_spec") or row.get("build_plan", {}).get("spec")]
            for owner in owners:
                if not owner or not (BUILD / owner).is_file():
                    errors.append(f"Missing build owner in {name}: {owner}")
    screens = load("driver-screens.json")
    expected = {str(f.relative_to(ROOT)) for f in (SOURCE / "ui/driver/screens").glob("*.html")}
    if {row["source"] for row in screens} != expected:
        errors.append("Driver reference coverage differs from imported HTML set")
    for row in screens:
        if row["candidate_code"] and not (ROOT / row["candidate_code"]).is_file():
            errors.append(f"Missing candidate file: {row['candidate_code']}")
        if row["functional_parity"] != "NOT_RUN" or row["visual_parity"] != "NOT_RENDERED":
            errors.append(f"Unsubstantiated acceptance status: {row['id']}")
    for path in load("ui-controls-static.json"):
        if not (ROOT / path).is_file():
            errors.append(f"Missing control reference: {path}")
    lock = load("source-lock.json")
    actual = {str(f.relative_to(ROOT)): hashlib.sha256(f.read_bytes()).hexdigest()
              for f in SOURCE.rglob("*") if f.is_file()}
    if actual != lock["files"]:
        errors.append("Source differs from audit lock")
    original = json.loads((BUILD / "original-source-lock.json").read_text())
    archive = ROOT / "specs/source/archives/Rounds-Complete-Project-v2.3.zip"
    archive_result = "NOT_AVAILABLE"
    if archive.is_file():
        if hashlib.sha256(archive.read_bytes()).hexdigest() != original["archive_sha256"]:
            errors.append("Source ZIP differs from recorded baseline")
        with zipfile.ZipFile(archive) as zipped:
            entries = [entry for entry in zipped.infolist() if not entry.is_dir()]
            if len(entries) != len(original["files"]):
                errors.append("ZIP and original locked file counts differ")
            for entry in entries:
                relative = Path(entry.filename).relative_to("Rounds-Complete-Project-v2.3")
                expected_hash = hashlib.sha256(zipped.read(entry)).hexdigest()
                path = str((SOURCE / relative).relative_to(ROOT))
                if original["files"].get(path) != expected_hash:
                    errors.append(f"ZIP/original-lock mismatch: {relative}")
                if str(relative).startswith(("ui/", "design/", "reference/")) or str(relative) == "OPEN-PROJECT.html":
                    published_hash = hashlib.sha256(publishable_reference_bytes(zipped.read(entry))).hexdigest()
                    if actual.get(path) != published_hash:
                        errors.append(f"Approved UI/reference changed beyond credential redaction: {relative}")
        archive_result = "CHECKED"
    else:
        errors.append("Missing original archive")
    recorded = load("reconciliation-changes.json")
    expected_changes = [{"path": p, "original_sha256": original["files"].get(p), "working_sha256": actual[p]}
                        for p in sorted(actual) if actual[p] != original["files"].get(p)]
    if recorded["changed_files"] != expected_changes or set(actual) != set(original["files"]):
        errors.append("Working-source changes do not match reconciliation record")
    modules = json.loads((BUILD / "MODULE-READINESS.json").read_text())
    evidence = load("repository-evidence.json")
    expected_paths = {p for card in modules["modules"] for p in card["code"] + card.get("tests", [])}
    if set(evidence) != expected_paths:
        errors.append("Repository evidence set differs from module cards")
    if len(modules["modules"]) != 14:
        errors.append("Expected fourteen module readiness cards")
    for card in modules["modules"]:
        if card["status"] not in {"READY_TO_IMPLEMENT", "BLOCKED_BY_DECISION", "DEFERRED"}:
            errors.append(f"Unknown readiness status: {card['id']}")
        for field in ["scope", "code", "retain", "adapt", "replace", "dependencies", "migration", "offline", "acceptance", "blocked"]:
            if field not in card:
                errors.append(f"Missing module field {card['id']}.{field}")
        for path in card["code"] + card.get("tests", []):
            if not (ROOT / path).is_file():
                errors.append(f"Missing actual repository path: {path}")
            baseline = subprocess.run(["git", "cat-file", "-e", modules["baseline_commit"] + ":" + path], cwd=ROOT, capture_output=True)
            if baseline.returncode:
                errors.append(f"Missing baseline repository path: {path}")
            elif path in evidence:
                data = subprocess.run(["git", "show", modules["baseline_commit"] + ":" + path], cwd=ROOT, capture_output=True, check=True).stdout
                if evidence[path]["baseline_sha256"] != hashlib.sha256(data).hexdigest():
                    errors.append(f"Repository baseline hash differs: {path}")
    runs = load("test-results.json")
    if runs["source_files"] != actual:
        errors.append("Local test evidence belongs to a different source fingerprint")
    for path, digest in runs["code_and_tool_files"].items():
        if not (ROOT / path).is_file() or hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != digest:
            errors.append(f"Local test evidence stale for code/tool: {path}")
    for check in runs["checks"]:
        log = ROOT / check["log"]
        if not log.is_file() or hashlib.sha256(log.read_bytes()).hexdigest() != check["log_sha256"]:
            errors.append(f"Missing/modified check log: {check['name']}")
        if check["status"] != "PASS" or check["exit_code"] != 0:
            errors.append(f"Local check not passed: {check['name']}")
    result = {"status": "FAIL" if errors else "PASS", "documents_checked": len(documents),
              "local_file_links_checked": links, "build_specs": 14,
              "source_files_hash_checked": len(actual), "source_zip": archive_result,
              "local_checks": runs["status"], "application_acceptance": "NOT_RUN", "errors": errors}
    (GENERATED / "build-check.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
