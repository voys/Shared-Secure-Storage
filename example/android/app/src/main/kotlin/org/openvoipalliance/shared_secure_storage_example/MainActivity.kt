package org.openvoipalliance.shared_secure_storage_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.openvoipalliance.sharedsecurestorage.SharedSecureStorage

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Only here so the example and its tests can show what native code sees.
        val storage = SharedSecureStorage.getInstance(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "example/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBeforeFlutter" -> result.success(ExampleApplication.valueReadBeforeFlutter)
                    "read" -> result.success(storage.read(call.arguments as String))
                    "write" -> {
                        val (key, value) = call.arguments as List<*>
                        storage.write(key as String, value as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
