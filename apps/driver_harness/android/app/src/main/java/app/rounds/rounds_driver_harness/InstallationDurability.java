package app.rounds.rounds_driver_harness;

import android.content.Context;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;
import java.util.UUID;

/** Disk barrier for the pinned flutter_secure_storage10.3.1 NEW namespace only.
 * No raw secret crosses this channel and no caller chooses a path/key/store.
 * Native kill/full-disk/encryption tests are still required before activation.
 */
public final class InstallationDurability {
    private static final String NAMESPACE = "rounds_v23_installations";
    private static final String MARKER = "__rounds_commit_marker_v1";

    interface CommitStore { boolean commit(String name); }

    static boolean flush(CommitStore store) {
        // Preserve key/config before acknowledging the encrypted record.
        return store.commit("FlutterSecureKeyStorage:" + NAMESPACE)
            && store.commit("FlutterSecureStorageConfiguration:" + NAMESPACE)
            && store.commit(NAMESPACE);
    }

    public static void install(FlutterEngine engine, Context context) {
        var messenger = engine.getDartExecutor().getBinaryMessenger();
        // Synchronous disk IO runs off the UI thread, on a serial task queue.
        var channel = new MethodChannel(messenger,
            "app.rounds/v23_installation_durability",
            StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue());
        channel.setMethodCallHandler((call, result) -> {
            if (!call.method.equals("flushV1") || call.arguments != null) {
                result.notImplemented();
                return;
            }
            try {
                // A changed non-secret marker forces a synchronous disk write;
                // an empty commit may not report an earlier failed apply().
                boolean committed = flush(name -> context.getSharedPreferences(name, Context.MODE_PRIVATE)
                    .edit().putString(MARKER, UUID.randomUUID().toString()).commit());
                if (committed) result.success(true);
                else result.error("SECURE_STORAGE_UNAVAILABLE", "Installation was not committed", null);
            } catch (Exception error) {
                result.error("SECURE_STORAGE_UNAVAILABLE", "Installation was not committed", null);
            }
        });
    }

    private InstallationDurability() {}
}
