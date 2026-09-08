import XCTest
@testable import QuoteDay

/// 챌린지 배점과 랭킹 검증.
///
/// 서버는 "내가 전체에서 어디쯤인지"만 알려 주고 점수 계산은 전부 기기에서 끝난다.
/// 그래서 여기서 검증하는 것이 곧 사용자가 보는 숫자다.
final class RankingTests: XCTestCase {

    // MARK: - 배점

    func testPointsRiseWithDifficulty() {
        let levels = ChallengeDifficulty.allCases.sorted { $0.rawValue < $1.rawValue }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            XCTAssertLessThan(
                lower.pointsPerQuestion,
                higher.pointsPerQuestion,
                "\(higher.rawValue)단계가 \(lower.rawValue)단계보다 배점이 높아야 한다."
            )
        }
    }

    /// 어려운 단계를 절반만 맞혀도 쉬운 단계를 다 맞힌 것보다 높아야 한다.
    /// 그러지 않으면 아무도 어려운 단계를 하지 않는다.
    func testHalfOfAHardRoundBeatsAPerfectEasyRound() {
        let easy = ChallengeDifficulty.beginner.perfectScore
        let halfHard = ChallengeScore.points(correctCount: 5, difficulty: .extreme)
        XCTAssertGreaterThan(halfHard, easy)

        let halfVeryHard = ChallengeScore.points(correctCount: 5, difficulty: .veryHard)
        XCTAssertGreaterThan(halfVeryHard, ChallengeDifficulty.normal.perfectScore)
    }

    func testPointsAreNeverNegative() {
        XCTAssertEqual(ChallengeScore.points(correctCount: -3, difficulty: .hard), 0)
        XCTAssertEqual(ChallengeScore.points(correctCount: 0, difficulty: .extreme), 0)
    }

    func testPerfectScoreMatchesAFullRound() {
        for difficulty in ChallengeDifficulty.allCases {
            XCTAssertEqual(
                difficulty.perfectScore,
                ChallengeScore.points(
                    correctCount: ChallengeGenerator.questionsPerRound,
                    difficulty: difficulty
                )
            )
        }
    }

    // MARK: - 총점

    /// 총점은 **최고 기록의 합**이다. 같은 판을 다시 돌아도 오르지 않아야 한다.
    func testTotalUsesBestScoresOnly() {
        let total = ChallengeScore.total { _, difficulty in
            difficulty == .beginner ? 10 : 0
        }
        // 두 모드 × 1단계 만점.
        XCTAssertEqual(total, 2 * ChallengeDifficulty.beginner.perfectScore)
    }

    func testMaximumTotalIsEveryModeAndLevelPerfect() {
        let total = ChallengeScore.total { _, _ in ChallengeGenerator.questionsPerRound }
        XCTAssertEqual(total, ChallengeScore.maximumTotal)
        XCTAssertGreaterThan(ChallengeScore.maximumTotal, 0)
    }

    @MainActor
    func testStoreTotalReflectsRecords() {
        let suite = "test.rank.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ChallengeStore(defaults: defaults)

        XCTAssertEqual(store.rankingTotal, 0)

        store.finish(
            mode: .fillInTheBlank, difficulty: .extreme,
            correctCount: 4, questionCount: 10, bestStreak: 2
        )
        XCTAssertEqual(store.rankingTotal, 4 * ChallengeDifficulty.extreme.pointsPerQuestion)

        // 더 낮은 점수로 다시 돌아도 총점은 그대로다.
        store.finish(
            mode: .fillInTheBlank, difficulty: .extreme,
            correctCount: 1, questionCount: 10, bestStreak: 1
        )
        XCTAssertEqual(store.rankingTotal, 4 * ChallengeDifficulty.extreme.pointsPerQuestion)
    }

    // MARK: - 구간

    func testBucketsCoverEveryPossibleScore() {
        for total in stride(from: 0, through: ChallengeScore.maximumTotal, by: 25) {
            let index = RankBucket.index(for: total)
            XCTAssertTrue(RankBucket.allIndices.contains(index), "\(total)점이 구간을 벗어났다.")
        }
        XCTAssertEqual(RankBucket.index(for: -100), 0, "음수도 첫 구간으로 떨어져야 한다.")
        XCTAssertEqual(
            RankBucket.index(for: ChallengeScore.maximumTotal * 10),
            RankBucket.count - 1,
            "상한을 넘겨도 마지막 구간에 머물러야 한다."
        )
    }

    func testBucketIndexRisesWithScore() {
        XCTAssertLessThanOrEqual(RankBucket.index(for: 0), RankBucket.index(for: 500))
        XCTAssertLessThan(RankBucket.index(for: 0), RankBucket.index(for: RankBucket.width * 3))
    }

    // MARK: - 순위

    /// 사람이 모자라면 순위를 내지 않는다. 세 명 중 한 명이 "상위 33%"인 것은 뜻이 없다.
    func testNoPercentileUntilEnoughPlayers() {
        let counts = [0: 2, 5: 1]
        let standing = RankStanding.from(counts: counts, total: 1_000)
        XCTAssertNil(standing.percentile)
        XCTAssertEqual(standing.playerCount, 3)
        XCTAssertTrue(standing.detail.contains("\(RankStanding.minimumPlayers)"))
        XCTAssertEqual(standing.headline, "1000점")
    }

    func testTopScorerIsInTheTopPercent() {
        // 100명, 나만 맨 위 구간에 있다.
        var counts = [Int: Int]()
        counts[0] = 99
        let top = RankBucket.index(for: ChallengeScore.maximumTotal)
        counts[top] = 1

        let standing = RankStanding.from(counts: counts, total: ChallengeScore.maximumTotal)
        XCTAssertEqual(standing.playerCount, 100)
        XCTAssertEqual(standing.percentile, 1, "맨 위면 상위 1% 여야 한다.")
        XCTAssertEqual(standing.headline, "상위 1%")
    }

    func testBottomScorerIsNotInTheTopPercent() {
        var counts = [Int: Int]()
        counts[0] = 1
        counts[RankBucket.index(for: ChallengeScore.maximumTotal)] = 99

        let standing = RankStanding.from(counts: counts, total: 0)
        XCTAssertEqual(standing.percentile, 100)
    }

    /// 점수가 높을수록 순위가 좋아져야 한다(퍼센트 숫자는 작아진다).
    func testHigherScoreNeverRanksWorse() {
        let counts = [0: 30, 1: 25, 2: 20, 3: 15, 4: 10]
        var previous = 101
        for total in stride(from: 0, to: RankBucket.width * 5, by: RankBucket.width) {
            guard let percentile = RankStanding.from(counts: counts, total: total).percentile else {
                return XCTFail("표본이 충분한데 순위가 없다.")
            }
            XCTAssertLessThanOrEqual(percentile, previous, "\(total)점에서 순위가 나빠졌다.")
            previous = percentile
        }
    }

    func testPercentileStaysInRange() {
        let counts = [0: 50, 3: 50]
        for total in stride(from: 0, through: ChallengeScore.maximumTotal, by: 100) {
            guard let percentile = RankStanding.from(counts: counts, total: total).percentile else {
                continue
            }
            XCTAssertGreaterThanOrEqual(percentile, 1)
            XCTAssertLessThanOrEqual(percentile, 100)
        }
    }

    // MARK: - 동기화가 없을 때

    /// 랭킹이 없어도 **점수는 보여야 한다.** 점수까지 감추면 자기가 얼마를 냈는지도 모른다.
    func testOfflineRankKeepsTheScoreVisible() async throws {
        let sync = OfflineRankSync()
        let availability = await sync.availability()
        XCTAssertEqual(availability, .notConfigured)
        XCTAssertNotNil(availability.message(subject: "랭킹"))

        let standing = try await sync.submit(total: 1_234)
        XCTAssertEqual(standing.total, 1_234)
        XCTAssertNil(standing.percentile)
        XCTAssertEqual(standing.headline, "1234점")
    }

    @MainActor
    func testRankStoreShowsTheScoreWhenSyncIsOff() async {
        let suite = "test.rank.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = RankStore(sync: OfflineRankSync(), defaults: defaults)

        await store.submit(total: 900)

        XCTAssertEqual(store.standing.total, 900)
        XCTAssertNil(store.standing.percentile)
        XCTAssertEqual(store.availability, .notConfigured)
    }

    func testCloudKitRankServiceIsNotCreatedWithoutAContainer() {
        XCTAssertNil(CloudKitRankService(containerIdentifier: nil))
        XCTAssertNil(CloudKitRankService(containerIdentifier: "  "))
    }
}
