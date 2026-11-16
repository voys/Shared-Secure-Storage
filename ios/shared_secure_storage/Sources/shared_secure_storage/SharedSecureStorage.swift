import Foundation
import Security

/// Key-value storage for secrets in the Keychain.
///
/// Usable from any native code, also when no Flutter engine is running. Dart reaches the same
/// values through the `SharedSecureStorage` class of this plugin.
///
/// Values can be read once the device has been unlocked for the first time after a restart, so
/// they are available in the background, and they never leave the device.
public final class SharedSecureStorage {
    public static let shared = SharedSecureStorage()

    public struct KeychainError: Error, CustomStringConvertible {
        public let status: OSStatus

        public var description: String { "Keychain OSStatus \(status)" }
    }

    // This is where existing installs keep their data, never change it.
    private let service = "shared_secure_storage"

    private init() {}

    /// The value for `key`, or nil when there is none.
    ///
    /// - Throws: `KeychainError` when the Keychain can't be read, e.g. before the first unlock
    ///   after a restart. Use `try?` to treat that as no value.
    public func read(_ key: String) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }

        return String(data: data, encoding: .utf8)
    }

    /// The values for `keys`, keys without a value are left out.
    public func read(_ keys: [String]) throws -> [String: String] {
        var values = [String: String]()
        for key in keys {
            values[key] = try read(key)
        }
        return values
    }

    public func write(_ value: String, for key: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            // Values must be readable in the background while the device is locked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        var status = SecItemUpdate(baseQuery(for: key) as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery(for: key).merging(attributes) { $1 } as CFDictionary, nil)
        }

        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func write(_ values: [String: String]) throws {
        for (key, value) in values {
            try write(value, for: key)
        }
    }

    public func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    public func delete(_ keys: [String]) throws {
        for key in keys {
            try delete(key)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
