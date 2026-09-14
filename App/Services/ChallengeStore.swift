import Foundation

/// 단계별 기록 하나.
struct ChallengeRecord: Codable, Hashable, Sendable {
    /// 한 판에서 맞힌 최고 개수.
    var bestScore: Int = 0
    /// 한 판 안에서 연속으로 맞힌 최고 기록.
    var bestStreak: Int = 0
    var playCount: Int = 0
    var totalAnswered: Int = 0
    var totalCorrect: Int = 0

    var accuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }

    var hasPlayed: Bool { playCount > 0 }
}

/// 챌린지 기록 저장소.
///
/// SwiftData 를 쓰지 않는 이유는 저장할 것이 단계마다 숫자 다섯 개뿐이기 때문이다.
/// 스키마를 늘리면 마이그레이션을 떠안게 되고, 얻는 것은 없다.
/// JSON 한 덩어리로 `UserDefaults` 에 넣는다.
///
/// ## 기록을 두 벌 둔다
///
///     이번 시즌   랭킹 점수의 근거. 1·4·7·10월 1일에 비워진다.
///     통산        지금까지의 최고 기록. 비워지지 않는다.
///
/// 랭킹만 다시 시작하고 사람이 쌓아 온 것은 지우지 않기 위함이다(`RankSeason` 참고).
@MainActor
@Observable
final class ChallengeStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var storedRecords: [String: ChallengeRecord]
    @ObservationIgnored private var storedLifetime: [String: ChallengeRecord]
    @ObservationIgnored private var storedSeason: String
    @ObservationIgnored private var storedLastMode: ChallengeMode

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.storedRecords = Self.load(from: defaults, key: SharedDefaultsKey.challengeRecords)
        self.storedLifetime = Self.load(from: defaults, key: SharedDefaultsKey.challengeRecordsLifetime)
        self.storedSeason = defaults.string(forKey: SharedDefaultsKey.challengeSeason) ?? ""
        self.storedLastMode = ChallengeMode(rawValue: defaults.string(forKey: SharedDefaultsKey.challengeMode) ?? "")
            ?? .fillInTheBlank
        refreshSeason()
    }

    // MARK: - 시즌

    /// 지금 시즌.
    var season: RankSeason { RankSeason.current() }

    /// 시즌이 바뀌었으면 이번 시즌 기록을 비운다. **통산 기록은 건드리지 않는다.**
    ///
    /// 앱을 켤 때와 다시 활성화될 때 부른다. 자정을 넘겨 백그라운드에 있다가
    /// 돌아오는 경우가 실제로 가장 흔하다.
    ///
    /// - Parameter season: 기준 시즌. 테스트가 경계를 넘겨 볼 수 있게 열어 둔다.
    func refreshSeason(_ season: RankSeason = RankSeason.current()) {
        let current = season.id
        guard storedSeason != current else { return }

        if storedSeason.isEmpty {
            // 시즌 개념이 없던 버전에서 올라온 기록이다. 지울 이유가 없다 —
            // 이번 시즌 것으로 삼고, 통산 기록이 비어 있으면 여기서 출발시킨다.
            if storedLifetime.isEmpty {
                storedLifetime = storedRecords
            }
        } else {
            withMutation(keyPath: \.records) {
                storedRecords = [:]
            }
        }

        storedSeason = current
        save()
    }

    // MARK: - 조회

    /// 이번 시즌 기록. 아직 없으면 0 으로 채운 값을 돌려준다.
    func record(mode: ChallengeMode, difficulty: ChallengeDifficulty) -> ChallengeRecord {
        access(keyPath: \.records)
        return storedRecords[Self.key(mode, difficulty)] ?? ChallengeRecord()
    }

    /// 통산 기록. 시즌이 바뀌어도 남는다.
    func lifetimeRecord(mode: ChallengeMode, difficulty: ChallengeDifficulty) -> ChallengeRecord {
        access(keyPath: \.records)
        return storedLifetime[Self.key(mode, difficulty)] ?? ChallengeRecord()
    }

    /// 관찰 등록용. 화면은 `record(mode:difficulty:)` 를 쓰면 된다.
    var records: [String: ChallengeRecord] {
        access(keyPath: \.records)
        return storedRecords
    }

    /// 한 번이라도 문제를 푼 적이 있는지. 빈 화면 문구를 고를 때 쓴다.
    var hasAnyRecord: Bool {
        access(keyPath: \.records)
        return storedRecords.values.contains { $0.hasPlayed }
    }

    /// 랭킹에 올라가는 **이번 시즌** 총점. 모드·단계별 최고 기록에 단계 배점을 곱해 더한다.
    var rankingTotal: Int {
        access(keyPath: \.records)
        return ChallengeScore.total { mode, difficulty in
            storedRecords[Self.key(mode, difficulty)]?.bestScore ?? 0
        }
    }

    /// 모드 전체의 최고 정답 수 합계. 홈 화면 요약에 쓴다.
    func totalBestScore(mode: ChallengeMode) -> Int {
        access(keyPath: \.records)
        return ChallengeDifficulty.allCases.reduce(0) { sum, difficulty in
            sum + (storedRecords[Self.key(mode, difficulty)]?.bestScore ?? 0)
        }
    }

    /// 마지막으로 고른 모드. 탭을 다시 열었을 때 그대로 이어지게 한다.
    var lastMode: ChallengeMode {
        get {
            access(keyPath: \.lastMode)
            return storedLastMode
        }
        set {
            withMutation(keyPath: \.lastMode) {
                storedLastMode = newValue
                defaults.set(newValue.rawValue, forKey: SharedDefaultsKey.challengeMode)
            }
        }
    }

    // MARK: - 기록

    /// 한 판이 끝났을 때 호출한다.
    /// - Returns: 최고 기록을 새로 썼으면 true.
    @discardableResult
    func finish(
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        correctCount: Int,
        questionCount: Int,
        bestStreak: Int
    ) -> Bool {
        // 시즌 경계를 막 넘었을 수 있다. 지난 시즌 기록 위에 얹지 않도록 먼저 본다.
        refreshSeason()

        let key = Self.key(mode, difficulty)
        var record = storedRecords[key] ?? ChallengeRecord()
        var lifetime = storedLifetime[key] ?? ChallengeRecord()

        // "최고 기록" 배지는 **이번 시즌** 기준이다. 시즌이 바뀌면 다시 세울 기회가 온다.
        let isNewRecord = correctCount > record.bestScore

        record.bestScore = max(record.bestScore, correctCount)
        record.bestStreak = max(record.bestStreak, bestStreak)
        record.playCount += 1
        record.totalAnswered += questionCount
        record.totalCorrect += correctCount

        lifetime.bestScore = max(lifetime.bestScore, correctCount)
        lifetime.bestStreak = max(lifetime.bestStreak, bestStreak)
        lifetime.playCount += 1
        lifetime.totalAnswered += questionCount
        lifetime.totalCorrect += correctCount

        withMutation(keyPath: \.records) {
            storedRecords[key] = record
            storedLifetime[key] = lifetime
        }
        save()
        return isNewRecord
    }

    /// 기록을 모두 지운다. 통산까지 함께 지운다. 설정에서 부를 수 있게 열어 둔다.
    func resetAll() {
        withMutation(keyPath: \.records) {
            storedRecords = [:]
            storedLifetime = [:]
        }
        defaults.removeObject(forKey: SharedDefaultsKey.challengeRecords)
        defaults.removeObject(forKey: SharedDefaultsKey.challengeRecordsLifetime)
    }

    // MARK: - 저장

    private static func key(_ mode: ChallengeMode, _ difficulty: ChallengeDifficulty) -> String {
        "\(mode.rawValue).\(difficulty.rawValue)"
    }

    private static func load(from defaults: UserDefaults, key: String) -> [String: ChallengeRecord] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder.quoteDay.decode([String: ChallengeRecord].self, from: data)
        } catch {
            // 기록이 깨졌다고 앱을 멈출 이유는 없다. 빈 기록으로 시작한다.
            AppLog.challenge.error("챌린지 기록 디코딩 실패: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func save() {
        defaults.set(storedSeason, forKey: SharedDefaultsKey.challengeSeason)
        write(storedRecords, to: SharedDefaultsKey.challengeRecords)
        write(storedLifetime, to: SharedDefaultsKey.challengeRecordsLifetime)
    }

    private func write(_ records: [String: ChallengeRecord], to key: String) {
        do {
            defaults.set(try JSONEncoder.quoteDay.encode(records), forKey: key)
        } catch {
            AppLog.challenge.error("챌린지 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
