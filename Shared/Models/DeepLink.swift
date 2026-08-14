import Foundation

/// 위젯 탭과 알림 탭에서 앱 내부 화면으로 이동하기 위한 URL 규약.
///
/// - `quoteday://quote/<uuid>` : 명언 상세
/// - `quoteday://schedule/<uuid>` : 일정 상세(캘린더 탭에서 해당 날짜 선택)
/// - `quoteday://today` : 홈 탭
public enum DeepLink: Equatable, Sendable {
    case quote(UUID)
    case schedule(UUID)
    case today

    public static let scheme = "quoteday"

    public var url: URL {
        switch self {
        case .quote(let id):
            URL(string: "\(Self.scheme)://quote/\(id.uuidString)") ?? Self.fallbackURL
        case .schedule(let id):
            URL(string: "\(Self.scheme)://schedule/\(id.uuidString)") ?? Self.fallbackURL
        case .today:
            Self.fallbackURL
        }
    }

    private static let fallbackURL = URL(string: "\(scheme)://today")!

    /// 잘못된 URL 이 들어와도 nil 만 돌려주고 크래시하지 않는다.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        // quoteday://quote/<uuid> 에서 host = "quote", path = "/<uuid>"
        let host = url.host?.lowercased() ?? ""
        let value = url.pathComponents.first(where: { $0 != "/" }) ?? ""

        switch host {
        case "quote":
            guard let id = UUID(uuidString: value) else { return nil }
            self = .quote(id)
        case "schedule":
            guard let id = UUID(uuidString: value) else { return nil }
            self = .schedule(id)
        case "today", "":
            self = .today
        default:
            return nil
        }
    }
}

/// 알림 `userInfo` 키. 문자열 오타를 막기 위해 한 곳에 모은다.
public enum NotificationPayloadKey {
    public static let deepLink = "deepLink"
    public static let quoteID = "quoteID"
    public static let scheduleID = "scheduleID"
    public static let category = "category"
}
