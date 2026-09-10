"""Refresh intentional working-source hashes, preserving the original archive/UI."""
from pathlib import Path
import hashlib
import json
import zipfile
from source_reference_provenance import publishable_reference_bytes

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "specs/build-v2.3"
SOURCE = ROOT / "specs/source/Rounds-Complete-Project-v2.3"
ARCHIVE = ROOT / "specs/source/archives/Rounds-Complete-Project-v2.3.zip"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files():
    return {str(f.relative_to(ROOT)): sha(f) for f in sorted(SOURCE.rglob("*")) if f.is_file()}


def main():
    original = json.loads((BUILD / "original-source-lock.json").read_text())
    assert sha(ARCHIVE) == original["archive_sha256"], "Original ZIP changed"
    with zipfile.ZipFile(ARCHIVE) as archive:
        archived_bytes = {str((SOURCE / Path(e.filename).relative_to(SOURCE.name)).relative_to(ROOT)):
                          archive.read(e) for e in archive.infolist() if not e.is_dir()}
    archived = {p: hashlib.sha256(data).hexdigest() for p, data in archived_bytes.items()}
    assert archived == original["files"], "Original per-file lock differs from original ZIP"
    before = files()
    assert set(before) == set(archived), "Unexpected source file additions/removals; review before refreshing"
    protected = [p for p in archived if "/ui/" in p or "/design/" in p or "/reference/" in p or p.endswith("OPEN-PROJECT.html")]
    assert all((ROOT / p).read_bytes() == publishable_reference_bytes(archived_bytes[p]) for p in protected), "Approved UI/assets or historical reference changed beyond reviewed credential removal"
    redacted = [p for p in protected if before[p] != archived[p]]
    # Each manifest excludes itself. Outer manifest includes the refreshed inner one.
    for scope, target in [(SOURCE / "specs", SOURCE / "specs/review/PACKAGE-SHA256.txt"),
                          (SOURCE, SOURCE / "PACKAGE-SHA256.txt")]:
        target.write_text("".join(f"{sha(f)}  {f.relative_to(scope)}\n" for f in sorted(scope.rglob("*"))
                                 if f.is_file() and f != target))
    after = files()
    changes = [{"path": p, "original_sha256": archived[p], "working_sha256": after[p]}
               for p in sorted(after) if after[p] != archived[p]]
    report = {"working_revision": "2.3-r1", "baseline_commit": original["baseline_commit"],
              "original_archive": str(ARCHIVE.relative_to(ROOT)), "original_sha256": sha(ARCHIVE),
              "source_files": len(after), "protected_ui_reference_files": len(protected),
              "approved_ui_assets_unchanged": not redacted,
              "approved_ui_content_unchanged_except_credential_redaction": True,
              "credential_redacted_reference_files": sorted(redacted), "changed_files": changes}
    target = BUILD / "generated/reconciliation-changes.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS original ZIP unchanged; {len(protected)} protected references match exactly after {len(redacted)} credential-only redactions; {len(changes)} working files reconciled")


if __name__ == "__main__":
    main()
