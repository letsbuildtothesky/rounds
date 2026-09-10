"""Local native seam tests only. Never installs the app or contacts live services."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
app = ROOT / 'apps/driver_harness'
flutter = Path(os.environ['ROUNDS_TEST_FLUTTER_BIN'])
assert flutter.is_absolute() and flutter.is_file(), 'Supply an explicit existing Flutter binary'
native_env = dict(os.environ)
# The pickup geometry fixture documents an SDK Roboto fallback. Flutter's
# default Ahem test font has deliberately different metrics: omitting this
# setup produces false layout failures. Always use the SAME SDK as the runner;
# this is geometry regression evidence, not source-font/visual acceptance.
native_env['ROUNDS_TEST_FLUTTER_SDK'] = str(flutter.resolve().parent.parent)
tests = ['test/v23_device_registration_test.dart', 'test/v23_legacy_upgrade_inventory_test.dart',
         'test/v23_encrypted_work_store_test.dart',
         'test/v23_legacy_recovery_archive_test.dart',
         'test/v23_storage_lifecycle_test.dart',
         'test/v23_startup_test.dart', 'test/v23_driver_auth_test.dart',
         'test/v23_offline_observation_test.dart',
         'test/v23_execution_query_test.dart',
         'test/v23_pickup_query_test.dart',
         'test/v23_pickup_issue_query_test.dart',
         'test/v23_pickup_collection_test.dart',
         'test/v23_pickup_issue_test.dart',
         'test/v23_pickup_photo_test.dart',
         'test/v23_pickup_issue_form_test.dart',
         'test/v23_pickup_issue_form_controller_test.dart',
         'test/v23_package_problem_view_test.dart',
         'test/v23_camera_capture_test.dart',
         'test/v23_offline_command_test.dart',
         'test/v23_photo_transfer_test.dart',
         'test/driver_command_outbox_test.dart', 'test/pod_evidence_outbox_test.dart',
         'test/delivery_exception_evidence_outbox_test.dart', 'test/message_media_outbox_test.dart',
         'test/driver_entry_api_test.dart', 'test/driver_identity_guard_test.dart',
         'test/driver_locale_sync_test.dart', 'test/driver_message_media_recovery_test.dart']
commands = [
    [str(flutter), '--version', '--machine'],
    [str(flutter), 'analyze', '--no-pub', 'lib/main.dart', 'lib/src/v23',
     'lib/src/driver/driver_api.dart', 'lib/src/driver/driver_auth_boundary.dart',
     'lib/src/storage/harness_database.dart', 'lib/src/storage/legacy_startup_gate.dart',
     'lib/src/app/harness_app_controller.dart', 'lib/src/driver/evidence_camera.dart',
     'lib/src/ui/proof_of_delivery_screen.dart',
     'lib/src/ui/components/pickup_collection_view.dart',
     'lib/src/ui/components/package_problem_view.dart',
     *[test for test in tests if test.startswith('test/v23_')], 'test/support/v23_sqlcipher_kill_worker.dart'],
    # Bound simultaneous compiler/listener copies on the development Mac.
    # This changes resource scheduling only, never the test set or assertions.
    [str(flutter), 'test', '--no-pub', '--concurrency', '2', '--reporter', 'expanded', *tests],
    # Startup/DriverApi are shared with all existing screens. Old goldens are
    # regression evidence only, never certification of the v2.3 design pack.
    [str(flutter), 'test', '--no-pub', '--concurrency', '2', '--reporter', 'expanded'],
]
for command in commands:
    print('RUN ' + ' '.join(command), flush=True)
    result = subprocess.run(command, cwd=app, env=native_env, timeout=240)
    if result.returncode:
        raise SystemExit(result.returncode)
print('PASS local native seam tests. Auth/HTTP/key vault mocked; SQLCipher/AES-GCM and files real synthetic fixtures, including legacy encrypted quarantine copies with injected interruption. No phone/OEM, account import/replay/cutover or release acceptance.', flush=True)
