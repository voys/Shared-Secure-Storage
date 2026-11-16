import 'package:pigeon/pigeon.dart';

// Regenerate with: dart run pigeon --input pigeons/shared_secure_storage.dart
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'shared_secure_storage',
    kotlinOut:
        'android/src/main/kotlin/org/openvoipalliance/sharedsecurestorage/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'org.openvoipalliance.sharedsecurestorage',
      errorClassName: 'SharedSecureStorageError',
    ),
    swiftOut:
        'ios/shared_secure_storage/Sources/shared_secure_storage/Messages.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'SharedSecureStorageError'),
  ),
)
@HostApi()
abstract class SharedSecureStorageApi {
  /// Keys without a value are left out of the result.
  @async
  Map<String, String> read(List<String> keys);

  @async
  void write(Map<String, String> values);

  @async
  void delete(List<String> keys);

  /// Where the Android Keystore key lives. Always null on iOS, and null on
  /// Android until the first value is written.
  @async
  String? keySecurityLevel();
}
