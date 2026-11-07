package io.github.kouotou.qoesense

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.kouotou.qoesense.collector.AndroidCollectorHost

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        TelemetryHostApi.setUp(messenger, AndroidCapabilityReporter(applicationContext))
        AndroidCollectorApi.setUp(messenger, AndroidCollectorHost(applicationContext))
    }
}
