import SwiftUI
import XCTest
@testable import QuoteDay

/// 하트 기능 검증.
///
/// CloudKit 자체는 시뮬레이터·CI 에서 확인할 수 없다. 그래서 `HeartSyncing` 을
/// 프로토콜로 끊어 두고, 여기서는 **화면이 실제로 의존하는 규칙**만 검증한다 —
/// 낙관적 갱신, 실패해도 되돌리지 않기, 밀린 것을 나중에 올리기.
final class HeartTests: XCTestCase {

    // MARK: - 가짜 동기화

    /// 서버 대역. actor 라서 여러 곳에서 동시에 불러도 안전하다.
    actor FakeHeartSync: HeartSyncing {
        /// 서버가 들고 있는 전체 하트 수.
        var serverCounts: [String: Int]
        /// 서버가 아는 내 하트.
        var serverMine: Set<String>
        /// 다음 호출을 실패시킬지.
        var shouldFail = false
        var status: CloudSyncAvailability = .ready
        private(set) var writes: [(slug: String, isOn: Bool)] = []

        init(counts: [String: Int] = [:], mine: Set<String> = []) {
            self.serverCounts = counts
            self.serverMine = mine
        }

        func setFailure(_ value: Bool) { shouldFail = value }
        func setStatus(_ value: CloudSyncAvailability) { status = value }
        func writeCount(for slug: String) -> Int { writes.filter { $0.slug == slug }.count }

        struct Failure: Error {}

        func availability() -> CloudSyncAvailability { status }

        func counts(for slugs: [String]) throws -> [String: Int] {
            if shouldFail { throw Failure() }
            return serverCounts.filter { slugs.contains($0.key) }
        }

        func myHearts(among slugs: [String]) throws -> Set<String> {
            if shouldFail { throw Failure() }
            return serverMine.intersection(slugs)
        }

        @discardableResult
        func setHeart(_ isOn: Bool, slug: String) throws -> Int {
            if shouldFail { throw Failure() }
            writes.append((slug, isOn))
            let had = serverMine.contains(slug)
            guard had != isOn else { return serverCounts[slug] ?? 0 }
            if isOn {
                serverMine.insert(slug)
                serverCounts[slug] = (serverCounts[slug] ?? 0) + 1
            } else {
                serverMine.remove(slug)
                serverCounts[slug] = max(0, (serverCounts[slug] ?? 0) - 1)
            }
            return serverCounts[slug] ?? 0
        }
    }

    /// 전송이 **겹치는지** 재는 서버 대역.
    ///
    /// 실기기에서 하트를 연타하면 탭마다 전송이 하나씩 떠서 같은 레코드를 동시에
    /// 읽고 썼다. CloudKit 쪽에서 `record to insert already exists` 와
    /// `client oplock error updating record` 가 났고 결국 요청이 조여졌다.
    /// 여기서는 한 번에 몇 개가 돌았는지만 센다.
    actor OverlapCountingHeartSync: HeartSyncing {
        private(set) var maxConcurrent = 0
        private(set) var writes: [(slug: String, isOn: Bool)] = []
        private var active = 0
        private var serverMine: Set<String> = []
        private var serverCounts: [String: Int] = [:]

        func mineOnServer() -> Set<String> { serverMine }

        func availability() -> CloudSyncAvailability { .ready }
        func counts(for slugs: [String]) -> [String: Int] { serverCounts }
        func myHearts(among slugs: [String]) -> Set<String> { serverMine.intersection(slugs) }

        func setHeart(_ isOn: Bool, slug: String) async throws -> Int {
            active += 1
            maxConcurrent = max(maxConcurrent, active)
            // 네트워크처럼 한 박자 쉰다. 겹치는 호출이 있으면 여기서 겹친다.
            try? await Task.sleep(for: .milliseconds(20))
            active -= 1

            writes.append((slug, isOn))
            let had = serverMine.contains(slug)
            guard had != isOn else { return serverCounts[slug] ?? 0 }
            if isOn {
                serverMine.insert(slug)
                serverCounts[slug] = (serverCounts[slug] ?? 0) + 1
            } else {
                serverMine.remove(slug)
                serverCounts[slug] = max(0, (serverCounts[slug] ?? 0) - 1)
            }
            return serverCounts[slug] ?? 0
        }
    }

    private let slugs = ["a", "b", "c"]

    @MainActor
    private func makeStore(
        sync: HeartSyncing,
        defaults: UserDefaults? = nil
    ) -> HeartStore {
        HeartStore(
            sync: sync,
            defaults: defaults ?? Self.cleanDefaults(),
            slugs: slugs,
            pushesImmediately: false
        )
    }

    private static func cleanDefaults() -> UserDefaults {
        let suite = "test.hearts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - 낙관적 갱신

    /// 하트를 누르면 네트워크를 기다리지 않고 그 자리에서 반영돼야 한다.
    @MainActor
    func testTogglingUpdatesTheScreenImmediately() {
        let store = makeStore(sync: FakeHeartSync())

        XCTAssertEqual(store.snapshot(for: "a"), HeartSnapshot(count: 0, isMine: false))

        store.toggle("a")
        XCTAssertEqual(store.snapshot(for: "a"), HeartSnapshot(count: 1, isMine: true))

        store.toggle("a")
        XCTAssertEqual(store.snapshot(for: "a"), HeartSnapshot(count: 0, isMine: false))
    }

    /// 같은 상태로 다시 설정하면 아무 일도 일어나지 않아야 한다.
    /// 그러지 않으면 한 사람이 숫자를 계속 올릴 수 있다.
    @MainActor
    func testSettingTheSameStateIsIgnored() {
        let store = makeStore(sync: FakeHeartSync())

        store.setHeart(true, for: "a")
        store.setHeart(true, for: "a")
        store.setHeart(true, for: "a")

        XCTAssertEqual(store.snapshot(for: "a").count, 1)
    }

    /// 합계는 0 아래로 내려가지 않는다.
    @MainActor
    func testCountNeverGoesBelowZero() {
        let store = makeStore(sync: FakeHeartSync())
        store.setHeart(true, for: "a")
        store.setHeart(false, for: "a")
        store.setHeart(false, for: "a")
        XCTAssertEqual(store.snapshot(for: "a").count, 0)
    }

    // MARK: - 서버로 올리기

    @MainActor
    func testPendingChangesReachTheServer() async {
        let fake = FakeHeartSync()
        let store = makeStore(sync: fake)

        store.toggle("a")
        XCTAssertTrue(store.hasPendingChanges)

        await store.synchronize()

        XCTAssertFalse(store.hasPendingChanges)
        let serverMine = await fake.serverMine
        XCTAssertTrue(serverMine.contains("a"))
    }

    /// 전송이 실패해도 **누른 하트를 되돌리지 않는다.**
    /// 되돌리면 사용자가 누른 것이 이유 없이 풀린다.
    @MainActor
    func testFailedPushKeepsTheHeartAndRetriesLater() async {
        let fake = FakeHeartSync()
        await fake.setFailure(true)
        let store = makeStore(sync: fake)

        store.toggle("a")
        await store.synchronize()

        XCTAssertTrue(store.isMine("a"), "실패했다고 하트가 풀리면 안 된다.")
        XCTAssertTrue(store.hasPendingChanges, "다시 시도할 수 있게 남아 있어야 한다.")

        // 연결이 돌아오면 밀린 것이 올라간다.
        await fake.setFailure(false)
        await store.synchronize()

        XCTAssertFalse(store.hasPendingChanges)
        let serverMine = await fake.serverMine
        XCTAssertTrue(serverMine.contains("a"))
    }

    /// 연타해도 같은 명언의 전송이 **겹치면 안 된다.**
    @MainActor
    func testRapidTapsNeverOverlapOnTheServer() async throws {
        let fake = OverlapCountingHeartSync()
        let store = HeartStore(
            sync: fake,
            defaults: Self.cleanDefaults(),
            slugs: slugs,
            pushesImmediately: true
        )

        for _ in 0..<5 { store.toggle("a") }   // 홀수 번 — 마지막은 켜짐
        XCTAssertTrue(store.isMine("a"))

        try await Self.waitUntilSettled(store)

        let overlap = await fake.maxConcurrent
        XCTAssertEqual(overlap, 1, "같은 명언의 전송이 동시에 돌면 안 된다.")

        let mine = await fake.mineOnServer()
        XCTAssertTrue(mine.contains("a"), "마지막으로 누른 상태가 서버에 남아야 한다.")
        XCTAssertTrue(store.isMine("a"))
    }

    /// 대기열이 빌 때까지 기다린다.
    @MainActor
    private static func waitUntilSettled(
        _ store: HeartStore,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date.now.addingTimeInterval(timeout)
        while store.hasPendingChanges {
            if Date.now > deadline {
                XCTFail("전송이 끝나지 않았다.")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - 서버 값 받아들이기

    @MainActor
    func testRefreshPullsServerCounts() async {
        let fake = FakeHeartSync(counts: ["a": 12, "b": 3], mine: ["b"])
        let store = makeStore(sync: fake)

        await store.refresh()

        XCTAssertEqual(store.snapshot(for: "a"), HeartSnapshot(count: 12, isMine: false))
        XCTAssertEqual(store.snapshot(for: "b"), HeartSnapshot(count: 3, isMine: true))
    }

    /// 방금 누른 하트를 서버 값이 덮어써서 화면에서 되풀리면 안 된다.
    @MainActor
    func testRefreshDoesNotOverwriteUnsentChanges() async {
        let fake = FakeHeartSync(counts: ["a": 5], mine: [])
        await fake.setFailure(true)
        let store = makeStore(sync: fake)

        store.toggle("a")
        await store.synchronize()   // 실패해서 대기열에 남는다
        await fake.setFailure(false)

        await store.refresh()

        XCTAssertTrue(store.isMine("a"))
    }

    /// 조회가 실패하면 화면의 숫자를 **건드리지 않는다.**
    ///
    /// 실패를 "아직 아무도 안 눌렀다"로 읽어 0 을 쓰는 것이
    /// 실기기에서 하트 수가 0 으로 튀던 원인이었다.
    @MainActor
    func testFailedRefreshKeepsTheLastKnownCounts() async {
        let fake = FakeHeartSync(counts: ["a": 7], mine: ["a"])
        let store = makeStore(sync: fake)

        await store.refresh()
        XCTAssertEqual(store.snapshot(for: "a"), HeartSnapshot(count: 7, isMine: true))

        await fake.setFailure(true)
        await store.refresh()

        XCTAssertEqual(store.snapshot(for: "a").count, 7, "조회가 실패했다고 0 으로 떨어지면 안 된다.")
        XCTAssertTrue(store.isMine("a"))
    }

    @MainActor
    func testRefreshIsSkippedWhenSyncIsUnavailable() async {
        let fake = FakeHeartSync(counts: ["a": 99])
        await fake.setStatus(.noAccount)
        let store = makeStore(sync: fake)

        await store.refresh()

        XCTAssertEqual(store.availability, .noAccount)
        XCTAssertEqual(store.snapshot(for: "a").count, 0, "쓸 수 없는 상태에서는 값을 받아오지 않는다.")
    }

    // MARK: - 저장

    @MainActor
    func testHeartsSurviveARestart() {
        let defaults = Self.cleanDefaults()

        let first = makeStore(sync: FakeHeartSync(), defaults: defaults)
        first.toggle("a")
        first.toggle("c")

        let reopened = makeStore(sync: FakeHeartSync(), defaults: defaults)
        XCTAssertTrue(reopened.isMine("a"))
        XCTAssertTrue(reopened.isMine("c"))
        XCTAssertFalse(reopened.isMine("b"))
        XCTAssertEqual(reopened.myHeartCount, 2)
        XCTAssertTrue(reopened.hasPendingChanges, "못 올린 것도 함께 남아야 한다.")
    }

    // MARK: - 표기

    func testCountFormatting() {
        XCTAssertEqual(HeartSnapshot(count: 0).displayCount, "0")
        XCTAssertEqual(HeartSnapshot(count: 999).displayCount, "999")
        XCTAssertEqual(HeartSnapshot(count: 1_200).displayCount, "1.2천")
        XCTAssertEqual(HeartSnapshot(count: 24_000).displayCount, "2.4만")
        XCTAssertEqual(HeartSnapshot(count: 130_000).displayCount, "13.0만")
        XCTAssertEqual(HeartSnapshot(count: 1_500_000).displayCount, "150만")
    }

    // MARK: - 동기화가 없는 구현

    func testOfflineSyncNeverBlocksTheHeart() async {
        let sync = OfflineHeartSync()
        let availability = await sync.availability()
        XCTAssertEqual(availability, .notConfigured)
        XCTAssertNotNil(availability.message(subject: "하트"), "왜 이 기기에만 남는지 알려 줘야 한다.")

        // 눌러도 아무 일도 일어나지 않는 하트보다는, 세지 않는 하트가 낫다.
        let total = try? await sync.setHeart(true, slug: "a")
        XCTAssertEqual(total, 1)
    }

    // MARK: - CloudKit 설정

    /// 컨테이너 식별자가 없으면 서비스 자체가 만들어지지 않아야 한다.
    /// 엔타이틀먼트 없이 CKContainer 를 건드리면 앱이 죽기 때문이다.
    func testCloudKitServiceIsNotCreatedWithoutAContainer() {
        XCTAssertNil(CloudKitHeartService(containerIdentifier: nil))
        XCTAssertNil(CloudKitHeartService(containerIdentifier: ""))
        XCTAssertNil(CloudKitHeartService(containerIdentifier: "   "))
    }
}
