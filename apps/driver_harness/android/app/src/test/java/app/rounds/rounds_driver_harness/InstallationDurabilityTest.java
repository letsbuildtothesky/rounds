package app.rounds.rounds_driver_harness;

import java.util.ArrayList;
import java.util.List;

/** JVM ordering/failure tests; not an Android disk/encryption/kill test. */
public final class InstallationDurabilityTest {
    public static void main(String[] arguments) {
        List<String> expected = List.of(
            "FlutterSecureKeyStorage:rounds_v23_installations",
            "FlutterSecureStorageConfiguration:rounds_v23_installations",
            "rounds_v23_installations");
        List<String> calls = new ArrayList<>();
        if (!InstallationDurability.flush(name -> { calls.add(name); return true; })
                || !calls.equals(expected)) throw new AssertionError("Commit order/namespace");
        for (int failure = 0; failure < 3; failure++) {
            final int failAt = failure;
            calls.clear();
            boolean result = InstallationDurability.flush(name -> {
                calls.add(name);
                return calls.size() - 1 != failAt;
            });
            if (result || !calls.equals(expected.subList(0, failure + 1)))
                throw new AssertionError("Failed commit must stop acknowledgment");
        }
        try {
            InstallationDurability.flush(name -> { throw new IllegalStateException("storage unavailable"); });
            throw new AssertionError("Storage exception must not acknowledge success");
        } catch (IllegalStateException expectedFailure) { /* Native handler sanitizes this. */ }
        System.out.println("PASS 5 Android barrier ordering/failure cases (JVM; disk operations mocked)");
    }
}
