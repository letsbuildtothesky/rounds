package app.rounds.rounds_driver_harness;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

public final class PrivateStorageRootTest {
    public static void main(String[] args) throws Exception {
        File root = Files.createTempDirectory("rounds-root-").toFile();
        File regular = new File(root, "file");
        try {
            var result = PrivateStorageRoot.describe(root);
            if (result.size() != 3 || !result.get("path").equals(root.getCanonicalPath())
                    || !result.get("policy").equals("android_no_backup") || !result.get("format").equals(1)) {
                throw new AssertionError("Unexpected native root contract");
            }
            Files.writeString(regular.toPath(), "test");
            for (File invalid : new File[] {null, new File("relative"), new File("/"), regular, new File(root, "missing")}) {
                try {
                    PrivateStorageRoot.describe(invalid);
                    throw new AssertionError("Accepted invalid root");
                } catch (IOException expected) { /* fail closed */ }
            }
            System.out.println("PASS native directory contract + five invalid-root cases; not Android OS execution");
        } finally {
            Files.deleteIfExists(regular.toPath());
            Files.delete(root.toPath());
        }
    }
}
