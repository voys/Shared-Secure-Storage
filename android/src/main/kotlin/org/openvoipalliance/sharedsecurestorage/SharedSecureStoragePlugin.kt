package org.openvoipalliance.sharedsecurestorage

import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Gives Dart access to [SharedSecureStorage], native code uses that class directly. */
class SharedSecureStoragePlugin : FlutterPlugin, SharedSecureStorageApi {
    private lateinit var storage: SharedSecureStorage

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        storage = SharedSecureStorage.getInstance(binding.applicationContext)
        SharedSecureStorageApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SharedSecureStorageApi.setUp(binding.binaryMessenger, null)
    }

    // The Keystore can be slow, so it's kept off the main thread. Calls still run one at a time
    // and in the order Dart made them, otherwise an older write could overtake a newer one.

    override suspend fun read(keys: List<String>) = inOrder { storage.read(keys) }

    override suspend fun write(values: Map<String, String>) = inOrder { storage.write(values) }

    override suspend fun delete(keys: List<String>) = inOrder { storage.delete(keys) }

    override suspend fun keySecurityLevel() = inOrder { storage.keySecurityLevel() }

    private suspend fun <T> inOrder(block: () -> T): T = withContext(queue) { block() }

    private companion object {
        private val queue = Dispatchers.IO.limitedParallelism(1)
    }
}
