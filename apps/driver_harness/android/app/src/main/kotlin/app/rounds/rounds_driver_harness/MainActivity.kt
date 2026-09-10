package app.rounds.rounds_driver_harness

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        InstallationDurability.install(flutterEngine, applicationContext)
        PrivateStorageRoot.install(flutterEngine, applicationContext)
    }
}
