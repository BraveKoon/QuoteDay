import Foundation

/// CloudKit 컨테이너 설정.
///
/// 식별자를 코드에 박지 않고 **Info.plist 에서 읽는다.** 이유는 하나다 —
/// 엔타이틀먼트 없이 `CKContainer` 를 건드리면 앱이 죽을 수 있는데,
/// CloudKit 프로비저닝은 유료 개발자 계정이 있어야 켤 수 있어서
/// 프로젝트를 그냥 열어 본 사람에게는 없을 수 있다.
///
/// 그런 빌드에서는 `QDCloudKitContainer` 키를 비우거나 지우면 된다.
/// 그러면 컨테이너 객체 자체가 만들어지지 않고, 하트는 기기 안에만 남는다.
/// (App Group 때 같은 실수를 했다 — 객체는 멀쩡히 만들어지고 나중에 죽었다.)
public enum CloudKitConfiguration {
    /// Info.plist 키 이름.
    public static let infoKey = "QDCloudKitContainer"

    /// 설정된 컨테이너 식별자. 없거나 비어 있으면 nil.
    public static let containerIdentifier: String? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }()

    public static var isConfigured: Bool { containerIdentifier != nil }
}
