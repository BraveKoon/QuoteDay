import Foundation
import Security

/// API 키를 **Keychain** 에 넣고 꺼낸다.
///
/// `UserDefaults` 에 넣지 않는 이유: 앱 샌드박스의 plist 는 기기 백업·파일
/// 추출로 그대로 새어 나갈 수 있다. Keychain 은 잠금 해제 상태에서만 복호화되고,
/// 이 기기에서만 쓰이도록(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
/// 붙여 둘 수 있다. 위젯과는 공유하지 않는다 — 위젯에 키가 필요 없다.
///
/// 키는 **절대 로그에 남기지 않는다.** 저장·조회 실패는 Bool 로만 알린다.
public enum KeychainStore {

    public enum Failure: Error {
        case unexpectedStatus(OSStatus)
    }

    /// 값을 넣거나 덮어쓴다.
    public static func set(_ value: String, for account: String, service: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw Failure.unexpectedStatus(errSecParam)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw Failure.unexpectedStatus(addStatus)
            }
        default:
            throw Failure.unexpectedStatus(status)
        }
    }

    /// 값을 읽는다. 없으면 nil.
    public static func get(for account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// 지운다. 없어도 성공으로 본다.
    public static func delete(for account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}


/// API 키를 두는 곳. 테스트에서는 메모리 구현을 끼워 넣는다.
///
/// 실제 Keychain 은 시뮬레이터·CI 에서 권한 문제로 실패할 수 있고, 테스트끼리
/// 상태를 공유한다. 그런 환경 요인과 무관하게 **앱 로직**을 검사하려면
/// 이 경계가 필요하다.
public protocol APIKeyStore: AnyObject {
    func key() -> String?
    @discardableResult func save(_ key: String) -> Bool
    func delete()
}

/// 실제 저장소. 앱이 쓰는 유일한 구현이다.
public final class KeychainAPIKeyStore: APIKeyStore {
    private let service: String
    private let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public func key() -> String? {
        KeychainStore.get(for: account, service: service)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    public func save(_ key: String) -> Bool {
        do {
            try KeychainStore.set(key, for: account, service: service)
            return true
        } catch {
            return false
        }
    }

    public func delete() {
        KeychainStore.delete(for: account, service: service)
    }
}
