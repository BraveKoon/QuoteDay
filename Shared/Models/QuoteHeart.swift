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

/// 다른 사용자와 값을 주고받을 수 있는 상태인지.
///
/// 하트와 챌린지 랭킹이 같은 CloudKit 컨테이너를 쓰므로 판정도 함께 쓴다.
/// 그래서 문구는 무엇이 집계되는지를 부르는 쪽이 붙이도록 비워 두었다.
public enum CloudSyncAvailability: Hashable, Sendable {
    /// 바로 주고받을 수 있다.
    case ready
    /// iCloud 에 로그인하지 않았다. 기록은 기기에만 남는다.
    case noAccount
    /// 이 빌드에 동기화가 설정되어 있지 않다(컨테이너 미지정).
    case notConfigured
    /// 네트워크·서버 문제. 잠시 뒤 다시 시도한다.
    case failed(String)

    public var isReady: Bool { self == .ready }

    /// 사용자에게 보여 줄 한 줄. 문제가 없으면 nil.
    /// - Parameter subject: 무엇이 집계되는지 (예: "하트", "랭킹").
    public func message(subject: String) -> String? {
        switch self {
        case .ready: nil
        case .noAccount: "iCloud 에 로그인하면 \(subject)이 다른 사람들과 함께 집계돼요."
        case .notConfigured: "이 빌드에서는 \(subject)이 이 기기에만 저장돼요."
        case .failed: "지금은 서버에서 값을 불러오지 못했어요. 연결되면 반영됩니다."
        }
    }
}
