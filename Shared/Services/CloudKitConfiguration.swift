import Foundation

/// CloudKit 컨테이너 설정.
///
/// 식별자를 코드에 박지 않고 **빌드 설정 → Info.plist** 를 거쳐 읽는다.
/// 이유는 하나다 — 엔타이틀먼트 없이 `CKContainer` 를 만들면 프로세스가 죽는다.
/// 그리고 CloudKit 엔타이틀먼트는 서명할 때 붙으므로, 서명을 끈 빌드에는 없다.
///
///     Info.plist   QDCloudKitContainer = $(QD_CLOUDKIT_CONTAINER)
///     빌드 설정     QD_CLOUDKIT_CONTAINER = iCloud.com.quoteday.app
///
/// 그래서 끄는 방법이 한 줄이다. `QD_CLOUDKIT_CONTAINER=""` 로 덮어쓰면
/// 이 값이 nil 이 되고, 컨테이너 객체 자체가 만들어지지 않는다.
/// CI 가 정확히 그렇게 한다(서명 없이 빌드하므로 켤 수가 없다).
/// CloudKit 을 켤 수 없는 계정도 같은 방법으로 끄면 된다.
///
/// **처음에는 Info.plist 에 값을 직접 적어 두었다가 CI 에서 앱이 시작하자마자
/// 죽었다.** 키가 있다는 것과 기능이 실제로 프로비저닝되었다는 것은 다르다 —
/// App Group 때 배운 것과 같은 교훈이고, 옷만 바꿔 입고 다시 나타났다.
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
