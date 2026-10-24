import Foundation

/// 클라우드에서 받아 온 변화 한 묶음.
public struct JournalRemoteChanges: Equatable, Sendable {
    /// 새로 생겼거나 고쳐진 기록.
    public let changed: [ArchivedNote]
    /// 지워진 기록.
    public let deleted: Set<UUID>

    public init(changed: [ArchivedNote] = [], deleted: Set<UUID> = []) {
        self.changed = changed
        self.deleted = deleted
    }

    public var isEmpty: Bool { changed.isEmpty && deleted.isEmpty }
}

/// 기록을 내 다른 기기와 주고받는 통로.
///
/// `HeartSyncing`·`RankSyncing` 과 같은 자리의 프로토콜이지만, **들어가는 곳이
/// 다르다.** 하트와 랭킹은 공개 데이터베이스로 가고 남들과 같이 집계되지만,
/// 기록은 **비공개 데이터베이스**로만 간다. 개발자도 볼 수 없는 곳이다.
///
/// 프로토콜로 끊어 두는 이유는 하트 때와 같다 — CloudKit 은 시뮬레이터에서도
/// CI 에서도 검증되지 않으므로, 테스트는 가짜 구현으로 돌린다.
public protocol JournalSyncing: Sendable {
    /// 지금 주고받을 수 있는 상태인지.
    func availability() async -> CloudSyncAvailability

    /// 지난번 이후 바뀐 것. 처음이면 클라우드에 있는 전부.
    func pull() async throws -> JournalRemoteChanges

    /// 올릴 것과 지울 것을 보낸다.
    ///
    /// `JournalSyncPlan` 을 통째로 받지 않고 둘로 나눠 받는다. 계획에는 기기에
    /// 할 일도 들어 있는데, 그것까지 넘기면 통로가 저장소를 건드릴 수 있는
    /// 모양이 된다. 통로는 올리고 내리기만 한다.
    ///
    /// **없는 레코드를 지우라는 요청이 올 수 있다.** 중복을 합칠 때 진 쪽이
    /// 이 기기에서만 있던 글이면 저쪽에는 애초에 없다. 구현체는 그 경우를
    /// 실패가 아니라 "이미 그 상태"로 다뤄야 한다(`CKError.unknownItem`).
    func push(upserts: [ArchivedNote], deletions: [UUID]) async throws

    /// 클라우드에 있는 이 앱의 기록을 통째로 지운다.
    ///
    /// **기기 것은 건드리지 않는다.** 사용자가 동기화를 끄면서 "iCloud 에서도
    /// 지워 주세요"를 고른 경우에만 부른다. 끄기만 하면 올라간 것은 그대로 남고,
    /// 그 사실을 화면에 적어 두어야 한다 — 껐으니 지워졌겠거니 하는 것이 가장
    /// 흔한 오해다.
    func eraseCloud() async throws
}

/// 동기화가 없는 구현. 프리뷰와 테스트, 그리고 컨테이너가 설정되지 않은 빌드에서 쓴다.
///
/// **기록을 막지 않는다.** 쓰고 읽는 것은 그대로 되고, 이 기기에만 남을 뿐이다.
/// 1.9.1 까지가 바로 이 상태다.
public struct OfflineJournalSync: JournalSyncing {
    public init() {}

    public func availability() async -> CloudSyncAvailability { .notConfigured }

    public func pull() async throws -> JournalRemoteChanges { JournalRemoteChanges() }

    public func push(upserts: [ArchivedNote], deletions: [UUID]) async throws {}

    public func eraseCloud() async throws {}
}
