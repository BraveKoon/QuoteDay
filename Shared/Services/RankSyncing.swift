import Foundation

/// 챌린지 랭킹을 다른 사용자와 주고받는 통로.
///
/// 하트와 같은 이유로 프로토콜로 끊어 둔다 — CloudKit 은 CI 에서 검증할 수 없고,
/// 나중에 서버를 바꾸더라도 화면은 그대로 두어야 한다.
public protocol RankSyncing: Sendable {
    func availability() async -> CloudSyncAvailability

    /// 내 총점을 올리고 갱신된 순위를 돌려준다.
    func submit(total: Int) async throws -> RankStanding

    /// 올리지 않고 지금 순위만 읽는다.
    func standing(total: Int) async throws -> RankStanding
}

/// 동기화가 없는 구현.
///
/// 점수는 그대로 보여 주고 **순위만 없다.** 랭킹이 없다고 점수까지 감추면
/// 사용자는 자기가 얼마를 냈는지도 알 수 없게 된다.
public struct OfflineRankSync: RankSyncing {
    public init() {}

    public func availability() async -> CloudSyncAvailability { .notConfigured }

    public func submit(total: Int) async throws -> RankStanding {
        RankStanding(total: total, percentile: nil, playerCount: 0)
    }

    public func standing(total: Int) async throws -> RankStanding {
        RankStanding(total: total, percentile: nil, playerCount: 0)
    }
}
