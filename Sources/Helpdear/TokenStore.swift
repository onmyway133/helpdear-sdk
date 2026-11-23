import Foundation
import Security

/// Keeps this device's visitor token, so the same person keeps their votes and ideas.
protocol TokenStore: Sendable {
    func token(for key: String) -> String?
    func save(_ token: String, for key: String)
    func remove(for key: String)
}

/// The visitor token in the Keychain, readable after the first unlock and never synced.
struct KeychainTokenStore: TokenStore {
    var service = "com.helpdear.sdk.visitor"

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    func token(for key: String) -> String? {
        var request = query(key)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String, for key: String) {
        let data = Data(token.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            let item = query(key).merging(attributes) { _, new in new }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func remove(for key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}

/// For tests and previews.
final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [String: String] = [:]

    func token(for key: String) -> String? {
        lock.withLock { tokens[key] }
    }

    func save(_ token: String, for key: String) {
        lock.withLock { tokens[key] = token }
    }

    func remove(for key: String) {
        lock.withLock { tokens[key] = nil }
    }
}
