import Foundation
import Security

/// A Keychain operation that returned something other than success.
public struct KeychainError: Error, Sendable, Equatable {
    public let status: OSStatus
}

/// Persists the signed-in server: the password in the Keychain, the `ServerConfig` in `UserDefaults`.
public struct CredentialStore {
    public static let defaultService = "nu.4z.plinket.subsonic"
    static let serverConfigDefaultsKey = "subsonic.serverConfig"

    private let service: String
    private let defaults: UserDefaults

    public init(service: String = defaultService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    public func serverConfig() -> ServerConfig? {
        guard let data = defaults.data(forKey: Self.serverConfigDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(ServerConfig.self, from: data)
    }

    public func saveServerConfig(_ config: ServerConfig) throws {
        defaults.set(try JSONEncoder().encode(config), forKey: Self.serverConfigDefaultsKey)
    }

    public func deleteServerConfig() {
        defaults.removeObject(forKey: Self.serverConfigDefaultsKey)
    }

    public func password(for config: ServerConfig) throws(KeychainError) -> String? {
        var query = itemQuery(for: config)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func savePassword(_ password: String, for config: ServerConfig) throws(KeychainError) {
        let query = itemQuery(for: config)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(status: updateStatus) }
        let addStatus = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    public func deletePassword(for config: ServerConfig) throws(KeychainError) {
        let status = SecItemDelete(itemQuery(for: config) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func itemQuery(for config: ServerConfig) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(config.username)@\(config.baseURL.absoluteString)",
        ]
    }
}
