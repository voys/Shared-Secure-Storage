# shared_secure_storage

Secure key-value storage that Dart and native code share.

Most secure storage plugins can only be used from Dart. This one is also a
plain Kotlin and Swift API, so native code can read a secret when no Flutter
engine is running. A typical case is answering a push message for an incoming
call before Flutter has started.

| | Storage |
|---|---|
| iOS | Keychain |
| Android | AES-256-GCM, with a key that never leaves the Android Keystore |

## Dart

```dart
final storage = SharedSecureStorage();

await storage.write('my_app.token', 'secret');
final token = await storage.read('my_app.token');
final values = await storage.readMany(['my_app.token', 'my_app.other']);
await storage.delete('my_app.token');
```

## Kotlin

```kotlin
val storage = SharedSecureStorage.getInstance(context)

val token: String? = storage.read("my_app.token")
storage.write("my_app.token", "secret")
storage.delete("my_app.token")
```

`getInstance` works with any `Context`, for example in `Application.onCreate`
or in a `FirebaseMessagingService`. Always go through `getInstance`. The single
synchronized instance is what makes concurrent use from Flutter and from
background threads safe.

Failures that the storage handles itself, such as a value that can't be
decrypted, are written to Logcat. Set `SharedSecureStorage.onError` to also
send them to your own logging.

## Swift

```swift
import shared_secure_storage

let token = try? SharedSecureStorage.shared.read("my_app.token")
try SharedSecureStorage.shared.write("secret", for: "my_app.token")
try SharedSecureStorage.shared.delete("my_app.token")
```

## Keys

Several packages in one app can use this storage, so:

- Prefix your keys, for example `my_package.token`.
- There is no "delete everything". Delete the keys you own.

## What to expect

- **Background access.** Values are readable while the device is locked, once
  it has been unlocked for the first time after a restart. Before that first
  unlock, reading throws on iOS.
- **No user authentication.** Values are not protected by biometrics or the
  device passcode prompt, because background code must be able to read them.
- **This device only.** Values are not included in iCloud Keychain or in
  backups to another device.
- **Reading never deletes.** On Android a value that can't be decrypted reads
  as `null` and is left in place.
- **The Android key is only replaced when it is certainly unusable**, or when
  nothing is stored. A write that fails for another reason throws and keeps
  the existing values.
- **One process on Android.** Use it from a single process. A service that
  runs in its own `android:process` has its own instance.
- **No app extensions on iOS yet.** Items are stored without a Keychain access
  group, so an extension can't read them.
- **iOS keeps values after the app is uninstalled.** That is how the Keychain
  works. Delete leftovers on first launch if that matters to you.

### Android backups

The encrypted values can't be decrypted on another device, so exclude them
from backup and device transfer. Otherwise a restored app finds values it can
never read. In your `data_extraction_rules.xml`, for both `<cloud-backup>` and
`<device-transfer>`:

```xml
<exclude domain="sharedpref" path="shared_secure_storage.xml" />
```

## Storage format

These names are a stable contract. They will not change in a compatible
release.

**iOS.** One generic password item per key:

| Attribute | Value |
|---|---|
| `kSecClass` | `kSecClassGenericPassword` |
| `kSecAttrService` | `shared_secure_storage` |
| `kSecAttrAccount` | the key |
| `kSecAttrAccessible` | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Value | the string as UTF-8 |

Native code that cannot link this package, such as another Flutter plugin, may
read and write these items directly.

**Android.** SharedPreferences file `shared_secure_storage`, one entry per key.
Each value is Base64 (no wrap) of a 12-byte IV followed by the AES-GCM
ciphertext with a 128-bit tag. The key is the Android Keystore entry
`shared_secure_storage`. On Android always use the `SharedSecureStorage` class
instead of reading this yourself.

## Development

```sh
dart run pigeon --input pigeons/shared_secure_storage.dart
dart format lib/src/messages.g.dart
flutter test
cd example && flutter test integration_test
```

The integration tests need a device or emulator, because the Keychain and the
Keystore don't exist in unit tests.
