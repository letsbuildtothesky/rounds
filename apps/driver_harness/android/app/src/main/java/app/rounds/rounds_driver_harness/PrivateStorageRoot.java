package app.rounds.rounds_driver_harness;

import android.content.Context;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;
import java.io.File;
import java.io.IOException;
import java.util.Map;

/** Returns only the OS-owned no-backup directory, with no caller path input. */
public final class PrivateStorageRoot {
    static Map<String, Object> describe(File noBackupDirectory) throws IOException {
        if (noBackupDirectory == null || !noBackupDirectory.isAbsolute()) throw new IOException();
        File root = noBackupDirectory.getCanonicalFile();
        if (!root.isDirectory() || root.getParentFile() == null) throw new IOException();
        return Map.of("format", 1, "policy", "android_no_backup", "path", root.getPath());
    }

    public static void install(FlutterEngine engine, Context context) {
        var messenger = engine.getDartExecutor().getBinaryMessenger();
        var channel = new MethodChannel(messenger, "app.rounds/v23_private_storage",
            StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue());
        channel.setMethodCallHandler((call, result) -> {
            if (!call.method.equals("rootV1") || call.arguments != null) {
                result.notImplemented();
                return;
            }
            try {
                result.success(describe(context.getNoBackupFilesDir()));
            } catch (Exception error) {
                result.error("PRIVATE_STORAGE_UNAVAILABLE", "Private storage is unavailable", null);
            }
        });
    }

    private PrivateStorageRoot() {}
}
