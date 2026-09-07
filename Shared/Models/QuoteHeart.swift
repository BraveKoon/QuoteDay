import Foundation

/// 명언 하나의 하트 상태.
///
/// `count` 는 **모든 사용자의 합계**이고 `isMine` 은 내가 눌렀는지다.
/// 둘은 따로 저장된다 — 합계는 서버에서 오고, 내 것은 기기에서도 안다.
public struct HeartSnapshot: Codable, Hashable, Sendable {
    public var count: Int
    public var isMine: Bool

    public init(count: Int = 0, isMine: Bool = false) {
        self.count = count
        self.isMine = isMine
    }

    /// 화면에 쓰는 표기. 네 자리부터는 한국어 단위로 줄여 쓴다.
    public var displayCount: String {
        switch count {
        case ..<0: "0"
        case ..<1_000: "\(count)"
        case ..<10_000: String(format: "%.1f천", Double(count) / 1_000)
        case ..<1_000_000: String(format: "%.1f만", Double(count) / 10_000)
        default: "\(count / 10_000)만"
        }
    }
}

/// 하트 동기화가 지금 가능한 상태인지.
public enum HeartSyncAvailability: Hashable, Sendable {
    /// 바로 주고받을 수 있다.
    case ready
    /// iCloud 에 로그인하지 않았다. 하트는 기기에만 남는다.
    case noAccount
    /// 이 빌드에 동기화가 설정되어 있지 않다(개발 중이거나 컨테이너 미지정).
    case notConfigured
    /// 네트워크·서버 문제. 잠시 뒤 다시 시도한다.
    case failed(String)

    public var isReady: Bool { self == .ready }

    /// 사용자에게 보여 줄 한 줄. 문제가 없으면 nil.
    public var message: String? {
        switch self {
        case .ready: nil
        case .noAccount: "iCloud 에 로그인하면 하트가 다른 사람들과 함께 집계돼요."
        case .notConfigured: "이 빌드에서는 하트가 이 기기에만 저장돼요."
        case .failed: "지금은 하트 수를 불러오지 못했어요. 눌러 둔 하트는 연결되면 반영됩니다."
        }
    }
}
