import Foundation

/// 하트의 로컬 상태와 서버 동기화를 함께 관리한다.
///
/// 화면은 항상 **즉시** 반응해야 한다. 하트를 누르면 네트워크를 기다리지 않고
/// 그 자리에서 색이 채워지고 숫자가 하나 오른다(낙관적 갱신). 서버 반영은 뒤에서 한다.
///
/// 그래서 세 가지를 기기에 남긴다.
///
/// - `counts` — 마지막으로 본 전체 하트 수. 오프라인에서도 숫자가 보이게 한다.
/// - `mine` — 내가 누른 명언. 서버가 없어도 하트는 눌린 채로 남는다.
/// - `pending` — 아직 서버에 못 올린 것. 다음 기회에 다시 시도한다.
///
/// 실패해도 되돌리지 않는 이유: 되돌리면 사용자가 누른 하트가 이유 없이 풀린다.
/// 대기열에 남겨 두고 다음에 올리는 편이 사용자가 기대하는 동작에 가깝다.
@MainActor
@Observable
final class HeartStore {

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sync: HeartSyncing
    @ObservationIgnored private let allSlugs: [String]
    /// 하트를 누른 즉시 서버로 보낼지.
    /// 테스트는 이것을 끄고 `synchronize()` 를 직접 불러 순서를 확정한다.
    @ObservationIgnored private let pushesImmediately: Bool

    @ObservationIgnored private var storedCounts: [String: Int]
    @ObservationIgnored private var storedMine: Set<String>
    /// 아직 서버에 올리지 못한 slug → 원하는 상태.
    @ObservationIgnored private var storedPending: [String: Bool]

    /// 지금 서버로 올리는 중인 slug. 같은 명언에 전송이 겹치지 않게 막는다.
    ///
    /// 연타하면 탭마다 전송이 하나씩 떠서 서로 경쟁했다. 같은 레코드를 동시에
    /// 읽고 쓰니 한쪽은 `record to insert already exists`, 합계 쪽은
    /// `client oplock error updating record` 가 났고, 결국 CloudKit 이
    /// 요청을 조이기 시작했다. 명언 하나당 전송은 하나만 돈다.
    @ObservationIgnored private var pushing: Set<String> = []

    private(set) var availability: CloudSyncAvailability = .notConfigured
    private(set) var isRefreshing = false

    init(
        sync: HeartSyncing,
        defaults: UserDefaults = AppGroup.defaults,
        slugs: [String] = QuoteLibrary.shared.quotes.map(\.slug),
        pushesImmediately: Bool = true
    ) {
        self.sync = sync
        self.defaults = defaults
        self.allSlugs = slugs
        self.pushesImmediately = pushesImmediately
        self.storedCounts = Self.decode([String: Int].self, from: defaults, key: SharedDefaultsKey.heartCounts) ?? [:]
        self.storedMine = Set(Self.decode([String].self, from: defaults, key: SharedDefaultsKey.heartMine) ?? [])
        self.storedPending = Self.decode([String: Bool].self, from: defaults, key: SharedDefaultsKey.heartPending) ?? [:]
    }

    // MARK: - 읽기

    /// 관찰 등록용. 화면은 `snapshot(for:)` 을 쓴다.
    var hearts: [String: Int] {
        access(keyPath: \.hearts)
        return storedCounts
    }

    func snapshot(for slug: String) -> HeartSnapshot {
        access(keyPath: \.hearts)
        return HeartSnapshot(count: storedCounts[slug] ?? 0, isMine: storedMine.contains(slug))
    }

    func isMine(_ slug: String) -> Bool {
        access(keyPath: \.hearts)
        return storedMine.contains(slug)
    }

    /// 내가 하트를 누른 명언 수. 설정 화면에서 보여 준다.
    var myHeartCount: Int {
        access(keyPath: \.hearts)
        return storedMine.count
    }

    /// 아직 서버에 못 올린 것이 남아 있는지.
    var hasPendingChanges: Bool {
        access(keyPath: \.hearts)
        return !storedPending.isEmpty
    }

    // MARK: - 쓰기

    /// 하트를 뒤집는다. 화면은 이 한 줄만 부르면 된다.
    func toggle(_ slug: String) {
        setHeart(!storedMine.contains(slug), for: slug)
    }

    func setHeart(_ isOn: Bool, for slug: String) {
        guard storedMine.contains(slug) != isOn else { return }

        withMutation(keyPath: \.hearts) {
            if isOn {
                storedMine.insert(slug)
                storedCounts[slug] = (storedCounts[slug] ?? 0) + 1
            } else {
                storedMine.remove(slug)
                storedCounts[slug] = max(0, (storedCounts[slug] ?? 0) - 1)
            }
            storedPending[slug] = isOn
        }
        persist()

        guard pushesImmediately else { return }
        schedulePush(slug: slug)
    }

    /// 이 명언의 전송을 예약한다. 이미 돌고 있으면 아무것도 하지 않는다 —
    /// 돌고 있는 쪽이 끝나면서 **그때의 최신 상태**를 다시 읽어 올리기 때문이다.
    private func schedulePush(slug: String) {
        guard !pushing.contains(slug) else { return }
        pushing.insert(slug)
        Task { @MainActor in
            defer { pushing.remove(slug) }
            // 올리는 동안 또 눌렀으면 대기열에 새 값이 남는다. 그것까지 올린다.
            while let isOn = storedPending[slug] {
                guard await push(slug: slug, isOn: isOn) else { break }
            }
        }
    }

    // MARK: - 동기화

    /// 앱이 활성화될 때 호출한다. 밀린 것을 올리고 최신 합계를 받아 온다.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        availability = await sync.availability()
        guard availability.isReady else { return }

        await synchronize()

        do {
            let counts = try await sync.counts(for: allSlugs)
            let mine = try await sync.myHearts(among: allSlugs)
            apply(counts: counts, mine: mine)
        } catch {
            availability = .failed(error.localizedDescription)
            AppLog.hearts.error("하트 동기화 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 서버 값을 그대로 받아들인다. 단, **아직 못 올린 것은 덮어쓰지 않는다** —
    /// 방금 누른 하트가 화면에서 되풀려 보이는 것을 막는다.
    private func apply(counts: [String: Int], mine: Set<String>) {
        withMutation(keyPath: \.hearts) {
            for slug in allSlugs where storedPending[slug] == nil {
                storedCounts[slug] = counts[slug] ?? 0
                if mine.contains(slug) {
                    storedMine.insert(slug)
                } else {
                    storedMine.remove(slug)
                }
            }
        }
        persist()
    }

    /// 아직 못 올린 하트를 지금 올린다. 하나가 실패해도 나머지는 계속 시도한다.
    func synchronize() async {
        for (slug, isOn) in storedPending where !pushing.contains(slug) {
            pushing.insert(slug)
            _ = await push(slug: slug, isOn: isOn)
            pushing.remove(slug)
        }
    }

    /// - Returns: 서버가 받아들였으면 true.
    @discardableResult
    private func push(slug: String, isOn: Bool) async -> Bool {
        do {
            let total = try await sync.setHeart(isOn, slug: slug)
            withMutation(keyPath: \.hearts) {
                // 올리는 사이에 또 눌렀으면 대기열의 값이 이미 달라져 있다.
                // 그때는 서버가 준 수도 한 박자 늦은 값이므로 화면을 되돌리지 않고,
                // 새 값이 올라간 다음에 맞춘다.
                guard storedPending[slug] == isOn else { return }
                storedCounts[slug] = total
                storedPending.removeValue(forKey: slug)
            }
            persist()
            return true
        } catch {
            // 대기열에 남겨 둔다. 되돌리지 않는다.
            AppLog.hearts.debug("하트 전송 보류(\(slug, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - 저장

    private func persist() {
        Self.encode(storedCounts, to: defaults, key: SharedDefaultsKey.heartCounts)
        Self.encode(Array(storedMine).sorted(), to: defaults, key: SharedDefaultsKey.heartMine)
        Self.encode(storedPending, to: defaults, key: SharedDefaultsKey.heartPending)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder.quoteDay.decode(type, from: data)
    }

    private static func encode(_ value: some Encodable, to defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder.quoteDay.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
