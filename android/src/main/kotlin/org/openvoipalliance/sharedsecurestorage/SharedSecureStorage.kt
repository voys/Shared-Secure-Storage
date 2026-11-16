package org.openvoipalliance.sharedsecurestorage

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.InvalidKeyException
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/**
 * Key-value storage for secrets, encrypted with an AES key that never leaves the Android Keystore.
 *
 * Usable from any native code with only a [Context], also when no Flutter engine is running. Dart
 * reaches the same values through the `SharedSecureStorage` class of this plugin.
 *
 * There is exactly one instance per process, see [getInstance], and every operation is
 * synchronized. That is what makes it safe to use from Flutter and e.g. a push message thread at
 * the same time, so never copy this class to create a second one.
 */
class SharedSecureStorage private constructor(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val keyStore by lazy { KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) } }
    private var cachedKey: SecretKey? = null

    /**
     * The value for [key], or null when there is none or when it can't be decrypted. Reading never
     * removes anything and never creates a key.
     */
    @Synchronized
    fun read(key: String): String? {
        val stored = prefs.getString(key, null) ?: return null

        return try {
            decrypt(stored)
        } catch (e: Exception) {
            report("Unable to decrypt '$key'", e)
            null
        }
    }

    /** The values for [keys], keys without a readable value are left out. */
    @Synchronized
    fun read(keys: Collection<String>): Map<String, String> =
        keys.mapNotNull { key -> read(key)?.let { key to it } }.toMap()

    fun write(key: String, value: String) = write(mapOf(key to value))

    /**
     * Stores all [values] or, when that fails, none of them.
     *
     * @throws Exception when the values can't be encrypted or stored. Existing values are kept,
     * unless the Keystore key turned out to be unusable for good.
     */
    @Synchronized
    fun write(values: Map<String, String>) {
        if (values.isEmpty()) return

        val encrypted = try {
            encrypt(values)
        } catch (e: Exception) {
            if (!isSafeToReplaceKey(e)) throw e

            // On some devices the key breaks, e.g. after an OS update. Without a new key nothing
            // could ever be stored again.
            report("Unable to encrypt, replacing the key", e)
            resetKey()
            encrypt(values)
        }

        val editor = prefs.edit()
        encrypted.forEach { (key, value) -> editor.putString(key, value) }
        check(editor.commit()) { "Unable to store values" }
    }

    fun delete(key: String) = delete(listOf(key))

    @Synchronized
    fun delete(keys: Collection<String>) {
        if (keys.isEmpty()) return

        val editor = prefs.edit()
        keys.forEach { editor.remove(it) }
        check(editor.commit()) { "Unable to remove values" }
    }

    /**
     * Where the Keystore key lives, e.g. `strongbox` or `trusted-environment`. Null as long as
     * nothing has been written, or when it can't be determined.
     */
    @Synchronized
    fun keySecurityLevel(): String? = try {
        existingKey()?.let(::securityLevelOf)
    } catch (e: Exception) {
        report("Unable to determine the key security level", e)
        null
    }

    /**
     * Null means the key definitely doesn't exist, the Keystore throws for any other failure.
     * `containsAlias` is avoided on purpose: on Android 12+ it also answers false when the
     * Keystore merely failed, which would lead to replacing a perfectly fine key.
     */
    private fun existingKey(): SecretKey? =
        cachedKey ?: (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.also { cachedKey = it }

    private fun encrypt(values: Map<String, String>): Map<String, String> {
        val key = existingKey() ?: run {
            // Values without their key can never be decrypted again.
            clearValues()
            generateKey().also { cachedKey = it }
        }

        return values.mapValues { (_, value) ->
            val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key) }
            val payload = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            Base64.encodeToString(payload, Base64.NO_WRAP)
        }
    }

    private fun decrypt(stored: String): String {
        val key = existingKey() ?: throw IllegalStateException("The Keystore key doesn't exist")
        val payload = Base64.decode(stored, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_LENGTH, payload, 0, IV_LENGTH))
        }

        return String(cipher.doFinal(payload, IV_LENGTH, payload.size - IV_LENGTH), Charsets.UTF_8)
    }

    /**
     * Replacing the key makes everything that is stored unreadable, so it only happens when the
     * Keystore is certain that the key can't be used anymore, or when there is nothing to lose.
     * Any other failure may be temporary and is passed on to the caller instead.
     */
    private fun isSafeToReplaceKey(e: Exception) =
        // Includes KeyPermanentlyInvalidatedException.
        e is InvalidKeyException || e is UnrecoverableKeyException || prefs.all.isEmpty()

    private fun resetKey() {
        cachedKey = null
        keyStore.deleteEntry(KEY_ALIAS)
        clearValues()
    }

    private fun clearValues() {
        if (prefs.all.isEmpty()) return
        check(prefs.edit().clear().commit()) { "Unable to remove values" }
    }

    private fun report(message: String, error: Throwable) {
        Log.w(TAG, message, error)
        runCatching { onError?.invoke(message, error) }
    }

    private fun generateKey(): SecretKey = KeyGenerator
        .getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        .apply {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    // Values must be readable in the background, without the user present.
                    .setUserAuthenticationRequired(false)
                    .build()
            )
        }
        .generateKey()

    private fun securityLevelOf(key: SecretKey): String {
        val info = SecretKeyFactory.getInstance(key.algorithm, ANDROID_KEYSTORE)
            .getKeySpec(key, KeyInfo::class.java) as KeyInfo

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            return if (info.isInsideSecureHardware) "secure-hardware" else "software"
        }

        return when (info.securityLevel) {
            KeyProperties.SECURITY_LEVEL_STRONGBOX -> "strongbox"
            KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "trusted-environment"
            KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE -> "unknown-secure"
            KeyProperties.SECURITY_LEVEL_SOFTWARE -> "software"
            else -> "unknown"
        }
    }

    companion object {
        private const val TAG = "SharedSecureStorage"

        // These three names are where existing installs keep their data, never change them.
        private const val PREFS_NAME = "shared_secure_storage"
        private const val KEY_ALIAS = "shared_secure_storage"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"

        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val IV_LENGTH = 12
        private const val TAG_LENGTH = 128

        /**
         * Called for failures that are handled here and would otherwise only show up in Logcat,
         * such as a value that can't be decrypted. Set it to pass them on to your own logging. It
         * can be called on any thread.
         */
        @Volatile
        @JvmStatic
        var onError: ((message: String, error: Throwable) -> Unit)? = null

        @Volatile
        private var instance: SharedSecureStorage? = null

        /** The one instance of this process, any [Context] will do. */
        @JvmStatic
        fun getInstance(context: Context): SharedSecureStorage =
            instance ?: synchronized(this) {
                instance ?: SharedSecureStorage(context.applicationContext).also { instance = it }
            }
    }
}
