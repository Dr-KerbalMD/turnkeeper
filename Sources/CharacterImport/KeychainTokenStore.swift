import Foundation
import Security

/// Keeps the token in the device's Keychain, never in the library, so it isn't synced or exported.
public struct KeychainTokenStore: Sendable {
    public var service: String
    public var account: String

    public init(service: String = "io.github.scooper4711.turnkeeper.demiplane", account: String = "graphql-token") {
        self.service = service
        self.account = account
    }

    public func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ token: String) throws {
        delete()
        var item = baseQuery
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CharacterImportError.rejected(operation: "Saving the Demiplane token", status: Int(status),
                                                message: "Keychain")
        }
    }

    public func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
