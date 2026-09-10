"""Compile real Android bridge against SDK/Flutter jars, test its commit ordering.
No APK/device/actual SharedPreferences execution is implied.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
java = Path(os.environ['ROUNDS_TEST_JAVA_BIN'])
android = Path(os.environ['ROUNDS_TEST_ANDROID_JAR'])
embedding = Path(os.environ['ROUNDS_TEST_FLUTTER_JAR'])
javac = java.with_name('javac')
for path in [java, javac, android, embedding]:
    assert path.is_absolute() and path.is_file(), f'Explicit local runtime missing: {path}'
print(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [android, embedding]}), flush=True)
subprocess.run([str(java), '-version'], check=True)
package = 'app/rounds/rounds_driver_harness'
base = ROOT / 'apps/driver_harness/android/app/src'
classpath = os.pathsep.join([str(android), str(embedding)])
with tempfile.TemporaryDirectory(prefix='rounds-v23-android-barrier-') as temp:
    subprocess.run([str(javac), '--release', '17', '-classpath', classpath, '-d', temp,
                    str(base / 'main/java' / package / 'InstallationDurability.java'),
                    str(base / 'main/java' / package / 'PrivateStorageRoot.java'),
                    str(base / 'test/java' / package / 'PrivateStorageRootTest.java'),
                    str(base / 'test/java' / package / 'InstallationDurabilityTest.java')], check=True, timeout=60)
    subprocess.run([str(java), '-classpath', temp + os.pathsep + classpath,
                    'app.rounds.rounds_driver_harness.InstallationDurabilityTest'], check=True, timeout=30)
    subprocess.run([str(java), '-classpath', temp + os.pathsep + classpath,
                    'app.rounds.rounds_driver_harness.PrivateStorageRootTest'], check=True, timeout=30)
