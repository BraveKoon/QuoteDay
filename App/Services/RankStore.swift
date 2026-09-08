import Foundation

/// 챌린지 랭킹 상태.
///
/// 점수 계산은 기기에서 끝난다(`ChallengeScore.total`). 서버가 하는 일은
/// **내 점수가 전체에서 어디쯤인지** 알려 주는 것뿐이다.
/// 그래서 동기화가 없어도 점수는 항상 보이고, 순위만 비어 있다.
@MainActor
@Observable
final class RankStore {

    @ObservationIgnored private let sync: RankSyncing
    @ObservationIgnored private let defaults: UserDefaults

    private(set) var standing: RankStanding
    private(set) var availability: CloudSyncAvailability = .notConfigured
    private(set) var isLoading = false

    init(sync: RankSyncing, defaults: UserDefaults = AppGroup.defaults) {
        self.sync = sync
        self.defaults = defaults
        // 지난번에 본 순위를 먼저 보여 준다. 시트를 열자마자 빈 화면을 보이지 않기 위해서다.
        self.standing = Self.load(from: defaults)
    }

    /// 총점을 올리고 순위를 갱신한다. 판이 끝났을 때와 랭킹 화면을 열 때 부른다.
    func submit(total: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        availability = await sync.availability()
        guard availability.isReady else {
            // 순위는 못 내도 점수는 내 것이다. 그대로 보여 준다.
            standing = RankStanding(total: total, percentile: nil, playerCount: 0)
            return
        }

        do {
            standing = try await sync.submit(total: total)
            persist()
        } catch {
            AppLog.challenge.error("랭킹 전송 실패: \(error.localizedDescription, privacy: .public)")
            availability = .failed(error.localizedDescription)
            standing = RankStanding(total: total, percentile: standing.percentile, playerCount: standing.playerCount)
        }
    }

    // MARK: - 저장

    private func persist() {
        defaults.set(standing.total, forKey: SharedDefaultsKey.rankTotal)
        defaults.set(standing.playerCount, forKey: SharedDefaultsKey.rankPlayerCount)
        if let percentile = standing.percentile {
            defaults.set(percentile, forKey: SharedDefaultsKey.rankPercentile)
        } else {
            defaults.removeObject(forKey: SharedDefaultsKey.rankPercentile)
        }
    }

    private static func load(from defaults: UserDefaults) -> RankStanding {
        RankStanding(
            total: defaults.integer(forKey: SharedDefaultsKey.rankTotal),
            percentile: defaults.object(forKey: SharedDefaultsKey.rankPercentile) as? Int,
            playerCount: defaults.integer(forKey: SharedDefaultsKey.rankPlayerCount)
        )
    }
}
