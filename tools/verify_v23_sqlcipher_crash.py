"""Actually SIGKILL our own SQLCipher child with a hot journal. No phone/data access."""
from pathlib import Path
import base64
import os
import selectors
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
app = ROOT / 'apps/driver_harness'
dart = Path(os.environ['ROUNDS_TEST_FLUTTER_BIN']).parent / 'cache/dart-sdk/bin/dart'
assert dart.is_file()
worker = 'test/support/v23_sqlcipher_kill_worker.dart'
with tempfile.TemporaryDirectory(prefix='rounds-cipher-kill-') as temp:
    directory = Path(temp)
    (directory / 'fixture-only').touch()
    key = base64.b64encode(os.urandom(32)).decode() + '\n'
    def run(mode):
        result = subprocess.run([str(dart), 'run', worker, mode, temp], cwd=app,
                                input=key, capture_output=True, text=True, timeout=45)
        assert result.returncode == 0, f'{mode} failed; no private output reflected'
        return result.stdout.strip()
    assert run('init') == 'INITIALIZED'
    child = subprocess.Popen([str(dart), 'run', worker, 'hold', temp], cwd=app,
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        child.stdin.write(key)
        child.stdin.flush()
        selector = selectors.DefaultSelector()
        selector.register(child.stdout, selectors.EVENT_READ)
        assert selector.select(timeout=45), 'Worker did not reach write barrier'
        assert child.stdout.readline().strip() == 'READY_TO_KILL', 'Worker failed before write barrier'
        assert run('lock') == 'LOCK_DENIED', 'Second process obtained active writer lock'
        journal = directory / 'cipher.db-journal'
        assert journal.is_file() and journal.stat().st_size > 4096, 'No hot rollback journal'
        for f in [directory / 'cipher.db', journal]:
            data = f.read_bytes()
            assert b'private-journal-canary-' not in data and b'confirmed-before-kill' not in data
        os.kill(child.pid, signal.SIGKILL)
        assert child.wait(timeout=10) == -signal.SIGKILL
        assert run('verify') == 'RECOVERED_ORIGINAL_COMMIT'
        print('PASS actual SQLCipher process-kill rollback, encrypted hot-journal bytes and cross-process writer lock.')
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=10)
        for stream in [child.stdin, child.stdout, child.stderr]:
            stream.close()
