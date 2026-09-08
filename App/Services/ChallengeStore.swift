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
@MainActor
@Observable
final class ChallengeStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var storedRecords: [String: ChallengeRecord]
    @ObservationIgnored private var storedLastMode: ChallengeMode

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.storedRecords = Self.load(from: defaults)
        self.storedLastMode = ChallengeMode(rawValue: defaults.string(forKey: SharedDefaultsKey.challengeMode) ?? "")
            ?? .fillInTheBlank
    }

    // MARK: - 조회

    /// 해당 모드·단계의 기록. 아직 없으면 0 으로 채운 값을 돌려준다.
    func record(mode: ChallengeMode, difficulty: ChallengeDifficulty) -> ChallengeRecord {
        access(keyPath: \.records)
        return storedRecords[Self.key(mode, difficulty)] ?? ChallengeRecord()
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

    /// 랭킹에 올라가는 총점. 모드·단계별 최고 기록에 단계 배점을 곱해 더한다.
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
        let key = Self.key(mode, difficulty)
        var record = storedRecords[key] ?? ChallengeRecord()

        let isNewRecord = correctCount > record.bestScore
        record.bestScore = max(record.bestScore, correctCount)
        record.bestStreak = max(record.bestStreak, bestStreak)
        record.playCount += 1
        record.totalAnswered += questionCount
        record.totalCorrect += correctCount

        withMutation(keyPath: \.records) {
            storedRecords[key] = record
        }
        save()
        return isNewRecord
    }

    /// 기록을 모두 지운다. 설정에서 부를 수 있게 열어 둔다.
    func resetAll() {
        withMutation(keyPath: \.records) {
            storedRecords = [:]
        }
        defaults.removeObject(forKey: SharedDefaultsKey.challengeRecords)
    }

    // MARK: - 저장

    private static func key(_ mode: ChallengeMode, _ difficulty: ChallengeDifficulty) -> String {
        "\(mode.rawValue).\(difficulty.rawValue)"
    }

    private static func load(from defaults: UserDefaults) -> [String: ChallengeRecord] {
        guard let data = defaults.data(forKey: SharedDefaultsKey.challengeRecords) else { return [:] }
        do {
            return try JSONDecoder.quoteDay.decode([String: ChallengeRecord].self, from: data)
        } catch {
            // 기록이 깨졌다고 앱을 멈출 이유는 없다. 빈 기록으로 시작한다.
            AppLog.challenge.error("챌린지 기록 디코딩 실패: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder.quoteDay.encode(storedRecords)
            defaults.set(data, forKey: SharedDefaultsKey.challengeRecords)
        } catch {
            AppLog.challenge.error("챌린지 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
