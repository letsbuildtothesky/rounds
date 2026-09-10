"""Build/check a local ARM64 debug APK. Never installs, uploads or enables v2.3."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import tempfile
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
app = ROOT / 'apps/driver_harness'
flutter = Path(os.environ['ROUNDS_TEST_FLUTTER_BIN'])
assert flutter.is_absolute() and flutter.is_file()
command = [str(flutter), 'build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-arm64']
print('RUN ' + ' '.join(command), flush=True)
result = subprocess.run(command, cwd=app, timeout=150)
if result.returncode:
    raise SystemExit(result.returncode)
apk = app / 'build/app/outputs/flutter-apk/app-debug.apk'
published_sha256 = 'b5a4be982aabc22ca89e7ffe7803952c41544d5f19cbc242fdd4a1d362d0fbae'
merged = app / 'build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libsqlcipher.so'
stripped = app / 'build/app/intermediates/stripped_native_libs/debug/stripDebugDebugSymbols/out/lib/arm64-v8a/libsqlcipher.so'
# AGP strips debug symbols, so APK bytes must not be compared directly with the
# upstream download hash. Verify the source, reproduce the NDK transformation
# in an owned temporary directory, and compare both Gradle's output and the APK.
assert hashlib.sha256(merged.read_bytes()).hexdigest() == published_sha256
extension = flutter.resolve().parents[1] / 'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt'
ndk_version = re.search(r'val ndkVersion: String = "([0-9.]+)"', extension.read_text()).group(1)
properties = (app / 'android/local.properties').read_text()
sdk = Path(re.search(r'^sdk.dir=(.+)$', properties, re.MULTILINE).group(1))
# Check only the new namespace exclusions, in both legacy cloud and modern
# cloud/device-transfer policies. No blanket change to legacy data retention.
resource = app / 'android/app/src/main/res/xml'
expected_prefs = {'rounds_v23_installations.xml',
                  'FlutterSecureKeyStorage:rounds_v23_installations.xml',
                  'FlutterSecureStorageConfiguration:rounds_v23_installations.xml'}
backup = ET.parse(resource / 'rounds_backup_rules.xml').getroot()
extraction = ET.parse(resource / 'rounds_data_extraction_rules.xml').getroot()
assert backup.tag == 'full-backup-content' and extraction.tag == 'data-extraction-rules'
assert [child.tag for child in extraction] == ['cloud-backup', 'device-transfer']
for rules in [backup, *extraction]:
    assert len(rules) == 3 and all(child.tag == 'exclude' for child in rules)
    assert {tuple(sorted(child.attrib.items())) for child in rules} == {
        tuple(sorted({'domain': 'sharedpref', 'path': name}.items())) for name in expected_prefs}
merged_manifest = app / 'build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml'
application = ET.parse(merged_manifest).getroot().find('application')
assert application.get('{http://schemas.android.com/apk/res/android}fullBackupContent') == '@xml/rounds_backup_rules'
assert application.get('{http://schemas.android.com/apk/res/android}dataExtractionRules') == '@xml/rounds_data_extraction_rules'
aapt = sdk / 'build-tools/36.1.0/aapt2'
assert aapt.is_file(), 'Pinned local resource-inspection tool missing'
for name, count in [('rounds_backup_rules', 1), ('rounds_data_extraction_rules', 2)]:
    dump = subprocess.run([str(aapt), 'dump', 'xmltree', '--file', f'res/xml/{name}.xml', str(apk)],
                          check=True, capture_output=True, text=True, timeout=30).stdout
    assert dump.count('E: exclude') == 3 * count
    # aapt2 also repeats each attribute in a '(Raw: ...)' annotation; count the
    # parsed attribute exactly once, not matching both representations.
    assert sorted(re.findall(r'^\s*A: path="([^"]+)"', dump, re.MULTILINE)) == sorted(list(expected_prefs) * count)
    assert re.findall(r'^\s*A: domain="([^"]+)"', dump, re.MULTILINE) == ['sharedpref'] * (3 * count)
    if count == 2:
        assert dump.count('E: cloud-backup') == 1 and dump.count('E: device-transfer') == 1
print('PASS merged manifest and compiled APK backup policies for new namespace; actual backup/restore NOT_RUN', flush=True)
strip_tools = list((sdk / 'ndk' / ndk_version / 'toolchains/llvm/prebuilt').glob('*/bin/llvm-strip'))
assert len(strip_tools) == 1, 'Expected the selected Flutter NDK strip tool'
with tempfile.TemporaryDirectory(prefix='rounds-sqlcipher-package-') as temporary:
    reproduced = Path(temporary) / 'libsqlcipher.so'
    subprocess.run([str(strip_tools[0]), '--strip-unneeded', '-o', str(reproduced), str(merged)], check=True, timeout=30)
    expected_library = reproduced.read_bytes()
assert stripped.read_bytes() == expected_library, 'Gradle library differs from verified source after stripping'
with zipfile.ZipFile(apk) as package:
    library = package.read('lib/arm64-v8a/libsqlcipher.so')
    assert library == expected_library, 'APK library differs from verified stripped source'
    dex = b''.join(package.read(n) for n in package.namelist() if n.endswith('.dex'))
    assert b'app.rounds/v23_installation_durability' in dex and b'InstallationDurability' in dex
    assert b'app.rounds/v23_private_storage' in dex and b'PrivateStorageRoot' in dex
print(json.dumps({'status': 'PASS', 'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
                  'published_sqlcipher_arm64_sha256': published_sha256,
                  'ndk_version': ndk_version,
                  'packaged_sqlcipher_arm64_sha256': hashlib.sha256(library).hexdigest(),
                  'meaning': 'Local Android ARM64 debug packaging/Activity bridge compilation only. No installation, native execution, store activation, backup/restore, release signing or license acceptance.'}), flush=True)
