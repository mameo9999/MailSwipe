import Foundation
import Security

protocol CredentialStoring {
    func load() throws -> MailAccountCredentials?
    func save(_ credentials: MailAccountCredentials) throws
    func clear() throws
}

enum CredentialStoreError: LocalizedError {
    case encodingFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "認証情報を保存用データに変換できませんでした。"
        case .keychain(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? "不明なエラー"
            return "Keychainの操作に失敗しました。\n\(detail)"
        }
    }
}

final class KeychainCredentialStore: CredentialStoring {
    private let service = "jp.ryuya.mailswipe.icloud"
    private let account = "primary-account"

    func load() throws -> MailAccountCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }
        guard let data = result as? Data else {
            throw CredentialStoreError.encodingFailed
        }

        return try JSONDecoder().decode(MailAccountCredentials.self, from: data)
    }

    func save(_ credentials: MailAccountCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemDelete(baseQuery as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
