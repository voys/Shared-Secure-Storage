import Flutter

/// Gives Dart access to `SharedSecureStorage`, native code uses that class directly.
public class SharedSecureStoragePlugin: NSObject, FlutterPlugin, SharedSecureStorageApi {
    private let storage = SharedSecureStorage.shared

    public static func register(with registrar: FlutterPluginRegistrar) {
        SharedSecureStorageApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: SharedSecureStoragePlugin()
        )
    }

    func read(keys: [String]) async throws -> [String: String] {
        try withKeychainErrors { try storage.read(keys) }
    }

    func write(values: [String: String]) async throws {
        try withKeychainErrors { try storage.write(values) }
    }

    func delete(keys: [String]) async throws {
        try withKeychainErrors { try storage.delete(keys) }
    }

    func keySecurityLevel() async throws -> String? {
        nil
    }

    private func withKeychainErrors<T>(_ block: () throws -> T) throws -> T {
        do {
            return try block()
        } catch let error as SharedSecureStorage.KeychainError {
            throw SharedSecureStorageError(
                code: "keychain",
                message: error.description,
                details: nil
            )
        }
    }
}
