"""Credential-only source publication guard; never prints a credential."""
from pathlib import Path
import hashlib
import json
import unittest
import zipfile

from source_reference_provenance import publishable_reference_bytes, PUBLIC_TOKEN

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "specs/source/Rounds-Complete-Project-v2.3"
ARCHIVE = ROOT / "specs/source/archives/Rounds-Complete-Project-v2.3.zip"


class SourcePublicationTests(unittest.TestCase):
    def test_original_archive_and_every_protected_reference(self):
        lock = json.loads((ROOT / "specs/build-v2.3/original-source-lock.json").read_text())
        self.assertEqual(hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(), lock["archive_sha256"])
        checked = changed = 0
        with zipfile.ZipFile(ARCHIVE) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                relative = Path(entry.filename).relative_to(SOURCE.name)
                if not (str(relative).startswith(("ui/", "design/", "reference/")) or str(relative) == "OPEN-PROJECT.html"):
                    continue
                original = archive.read(entry)
                expected = publishable_reference_bytes(original)
                actual = (SOURCE / relative).read_bytes()
                self.assertEqual(actual, expected, str(relative))
                self.assertIsNone(PUBLIC_TOKEN.search(actual), str(relative))
                self.assertNotEqual(actual + b" ", expected, "Any extra layout/copy byte must still differ")
                changed += original != actual
                checked += 1
        self.assertEqual(checked, 116)
        self.assertEqual(changed, 8)

    def test_clean_bytes_preserved_exactly(self):
        original = b'<button style="padding: 18px">Review address</button>\r\n'
        self.assertEqual(publishable_reference_bytes(original), original)

    def test_unknown_token_cannot_expand_redaction_exception(self):
        with self.assertRaisesRegex(ValueError, "Unreviewed"):
            publishable_reference_bytes(b"pk." + b"eyJunreviewed.synthetic")


if __name__ == "__main__":
    unittest.main()
