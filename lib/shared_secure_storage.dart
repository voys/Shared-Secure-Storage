import 'package:meta/meta.dart';

import 'src/messages.g.dart';

/// Key-value storage for secrets, kept in the iOS Keychain or encrypted with
/// the Android Keystore.
///
/// Native code reads and writes the same values through the
/// `SharedSecureStorage` class in Kotlin and Swift, also when Flutter isn't
/// running.
///
/// There is no way to remove everything at once, because several packages can
/// keep values here. Prefix your keys, e.g. `my_package.token`, and delete the
/// keys you own.
class SharedSecureStorage {
  SharedSecureStorage({@visibleForTesting SharedSecureStorageApi? api})
    : _api = api ?? SharedSecureStorageApi();

  final SharedSecureStorageApi _api;

  /// The value for [key], or `null` when there is none.
  ///
  /// On iOS this throws a `PlatformException` when the Keychain can't be read,
  /// which is the case before the first unlock after a restart. On Android a
  /// value that can't be decrypted is reported as `null`.
  Future<String?> read(String key) async => (await readMany([key]))[key];

  /// The values for [keys], keys without a value are left out.
  Future<Map<String, String>> readMany(Iterable<String> keys) =>
      _api.read(keys.toList());

  Future<void> write(String key, String value) => writeMany({key: value});

  Future<void> writeMany(Map<String, String> values) => _api.write(values);

  Future<void> delete(String key) => deleteMany([key]);

  Future<void> deleteMany(Iterable<String> keys) => _api.delete(keys.toList());

  /// Where the Android Keystore key lives, e.g. `strongbox` or
  /// `trusted-environment`. `null` on iOS, and on Android as long as nothing
  /// has been written.
  Future<String?> keySecurityLevel() => _api.keySecurityLevel();
}
