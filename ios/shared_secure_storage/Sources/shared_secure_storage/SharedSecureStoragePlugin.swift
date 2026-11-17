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

    // These run on the main actor so calls are handled one at a time and in the order Dart made
    // them, otherwise an older write could overtake a newer one.

    @MainActor
    func read(keys: [String]) async throws -> [String: String] {
        try withKeychainErrors { try storage.read(keys) }
    }

    @MainActor
    func write(values: [String: String]) async throws {
        try withKeychainErrors { try storage.write(values) }
    }

    @MainActor
    func delete(keys: [String]) async throws {
        try withKeychainErrors { try storage.delete(keys) }
    }

    @MainActor
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
