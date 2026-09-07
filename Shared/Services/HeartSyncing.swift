import Foundation

/// 하트를 다른 사용자와 주고받는 통로.
///
/// 프로토콜로 끊어 둔 이유는 두 가지다.
/// - CloudKit 은 시뮬레이터·CI 에서 검증할 수 없다. 테스트는 가짜 구현으로 돌린다.
/// - 나중에 서버를 바꾸더라도 `HeartStore` 와 화면은 그대로 둘 수 있다.
public protocol HeartSyncing: Sendable {
    /// 지금 주고받을 수 있는 상태인지. 네트워크를 타므로 async 다.
    func availability() async -> HeartSyncAvailability

    /// 여러 명언의 **전체 하트 수**를 한 번에 읽는다. 없는 명언은 결과에서 빠진다.
    func counts(for slugs: [String]) async throws -> [String: Int]

    /// 내가 하트를 누른 명언들.
    func myHearts(among slugs: [String]) async throws -> Set<String>

    /// 하트를 켜거나 끈다.
    /// - Returns: 반영된 뒤의 전체 하트 수.
    @discardableResult
    func setHeart(_ isOn: Bool, slug: String) async throws -> Int
}

/// 동기화가 없는 구현. 프리뷰와 테스트, 그리고 컨테이너가 설정되지 않은 빌드에서 쓴다.
///
/// **하트를 막지 않는다.** 누르는 것은 되고, 합계만 내 것만 센다.
/// 눌러도 아무 반응이 없는 하트보다는 이쪽이 낫다.
public struct OfflineHeartSync: HeartSyncing {
    public init() {}

    public func availability() async -> HeartSyncAvailability { .notConfigured }

    public func counts(for slugs: [String]) async throws -> [String: Int] { [:] }

    public func myHearts(among slugs: [String]) async throws -> Set<String> { [] }

    @discardableResult
    public func setHeart(_ isOn: Bool, slug: String) async throws -> Int { isOn ? 1 : 0 }
}
