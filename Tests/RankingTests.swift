import CloudKit
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

    /// 20등 안에 들면 **등수**로 말한다. "상위 3%" 보다 "7등" 이 분명하다.
    func testTopRanksAreShownAsAPlace() {
        let counts = [0: 2, 5: 1]                       // 세 명, 나는 맨 위 구간
        let standing = RankStanding.from(counts: counts, total: 1_000)

        XCTAssertEqual(standing.playerCount, 3)
        XCTAssertEqual(standing.rank, 1)
        XCTAssertEqual(standing.headline, "1등", "20등 안이면 등수로 말한다.")
        XCTAssertEqual(standing.detail, "3명 중 1000점")
    }

    /// 20등 밖이면 퍼센트로 말한다. 500등인 사람에게 "500등" 은 막막하기만 하다.
    func testRanksBelowTheLimitAreShownAsAPercentile() {
        let counts = [0: 100]                           // 100명이 모두 같은 구간
        let standing = RankStanding.from(counts: counts, total: 0)

        XCTAssertEqual(standing.rank, 50)
        XCTAssertGreaterThan(standing.rank ?? 0, RankStanding.rankDisplayLimit)
        XCTAssertEqual(standing.headline, "상위 50%")
    }

    /// 경계에서 표시가 바뀐다.
    func testTheLimitIsTheBoundaryBetweenPlaceAndPercentile() {
        // 위에 19명, 내 구간에 나 혼자 → 20등.
        let atLimit = RankStanding.from(counts: [0: 1, 5: 19], total: 0)
        XCTAssertEqual(atLimit.rank, RankStanding.rankDisplayLimit)
        XCTAssertEqual(atLimit.headline, "20등")

        // 위에 20명 → 21등. 여기서부터 퍼센트다.
        let pastLimit = RankStanding.from(counts: [0: 1, 5: 20], total: 0)
        XCTAssertEqual(pastLimit.rank, RankStanding.rankDisplayLimit + 1)
        XCTAssertTrue(pastLimit.headline.hasPrefix("상위 "))
    }

    /// 나 혼자여도 감추지 않는다.
    func testASinglePlayerStillSeesARank() {
        let standing = RankStanding.from(counts: [0: 1], total: 120)
        XCTAssertEqual(standing.playerCount, 1)
        XCTAssertEqual(standing.rank, 1)
        XCTAssertEqual(standing.headline, "1등")
    }

    /// 아무 기록도 없으면 점수만 보여 준다.
    func testNoPlayersFallsBackToTheScore() {
        let standing = RankStanding.from(counts: [:], total: 640)
        XCTAssertEqual(standing.playerCount, 0)
        XCTAssertNil(standing.rank)
        XCTAssertNil(standing.percentile)
        XCTAssertEqual(standing.headline, "640점")
    }

    /// 등수는 1 과 전체 인원 사이를 벗어나지 않는다.
    func testRankStaysWithinThePlayerCount() {
        let counts = [0: 3, 2: 4, 4: 2]                 // 아홉 명
        for total in stride(from: 0, through: ChallengeScore.maximumTotal, by: 100) {
            let standing = RankStanding.from(counts: counts, total: total)
            guard let rank = standing.rank else { return XCTFail("등수가 없다.") }
            XCTAssertGreaterThanOrEqual(rank, 1)
            XCTAssertLessThanOrEqual(rank, standing.playerCount)
        }
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
        XCTAssertEqual(standing.rank, 1)
        XCTAssertEqual(standing.headline, "1등", "1등은 퍼센트보다 등수가 분명하다.")
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
        let counts = [0: 50, 3: 50]   // 100명 — 퍼센트 구간
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

    // MARK: - 레코드 이름

    /// 공개 데이터베이스에는 CloudKit 이 만든 `Users` 레코드가 이미 들어 있고
    /// 그 이름은 사용자 레코드 이름 그 자체다. 우리가 같은 이름으로 저장하면
    /// 새 레코드 타입이 만들어지는 대신 시스템 `Users` 레코드에 필드가 붙는다.
    /// 한 번 그렇게 새어 나간 적이 있어서 이름 규칙을 테스트로 못 박는다.
    func testOurRecordNamesNeverCollideWithTheUserRecord() {
        let user = CKRecord.ID(recordName: "_abc123def456")
        let season = RankSeason(year: 2026, quarter: 1)

        XCTAssertNotEqual(
            CloudKitRankService.scoreID(season: season, user: user).recordName,
            user.recordName
        )
        XCTAssertNotEqual(
            CloudKitHeartService.heartID(slug: "churchill-courage", user: user).recordName,
            user.recordName
        )

        for index in RankBucket.allIndices {
            XCTAssertNotEqual(
                CloudKitRankService.bucketID(season: season, index).recordName,
                user.recordName
            )
        }
    }

    /// 점수 레코드와 구간 레코드가 서로 겹치지 않아야 한다.
    func testScoreAndBucketNamesDoNotOverlap() {
        let season = RankSeason(year: 2026, quarter: 1)
        let user = CKRecord.ID(recordName: "rank-bucket|\(season.id)|0")
        XCTAssertNotEqual(
            CloudKitRankService.scoreID(season: season, user: user).recordName,
            CloudKitRankService.bucketID(season: season, 0).recordName
        )
    }

    /// 시즌이 바뀌면 **읽고 쓰는 레코드가 통째로 바뀌어야** 리셋이 된다.
    func testRecordNamesChangeWithTheSeason() {
        let user = CKRecord.ID(recordName: "_abc123def456")
        let first = RankSeason(year: 2026, quarter: 1)
        let second = RankSeason(year: 2026, quarter: 2)

        XCTAssertNotEqual(
            CloudKitRankService.scoreID(season: first, user: user).recordName,
            CloudKitRankService.scoreID(season: second, user: user).recordName
        )
        XCTAssertNotEqual(
            CloudKitRankService.bucketID(season: first, 0).recordName,
            CloudKitRankService.bucketID(season: second, 0).recordName
        )
        XCTAssertTrue(
            CloudKitRankService.bucketID(season: first, 3).recordName.contains(first.id)
        )
    }

    // MARK: - 시즌

    /// 1·4·7·10월 1일에 시즌이 바뀐다.
    func testSeasonBoundariesAreTheFirstOfJanAprJulOct() {
        let calendar = Self.seoul
        let cases: [(month: Int, day: Int, quarter: Int)] = [
            (1, 1, 1), (3, 31, 1),
            (4, 1, 2), (6, 30, 2),
            (7, 1, 3), (9, 30, 3),
            (10, 1, 4), (12, 31, 4)
        ]
        for item in cases {
            let date = Self.date(2026, item.month, item.day, calendar)
            let season = RankSeason.current(date, calendar: calendar)
            XCTAssertEqual(season.quarter, item.quarter, "2026-\(item.month)-\(item.day)")
            XCTAssertEqual(season.year, 2026)
        }
    }

    func testSeasonIdentityAndStartMonth() {
        XCTAssertEqual(RankSeason(year: 2026, quarter: 1).id, "2026Q1")
        XCTAssertEqual(RankSeason(year: 2026, quarter: 3).title, "2026년 3분기")
        XCTAssertEqual(RankSeason(year: 2026, quarter: 1).startMonth, 1)
        XCTAssertEqual(RankSeason(year: 2026, quarter: 2).startMonth, 4)
        XCTAssertEqual(RankSeason(year: 2026, quarter: 3).startMonth, 7)
        XCTAssertEqual(RankSeason(year: 2026, quarter: 4).startMonth, 10)
    }

    /// 4분기 다음은 이듬해 1분기다.
    func testSeasonWrapsAtTheEndOfTheYear() {
        let last = RankSeason(year: 2026, quarter: 4)
        XCTAssertEqual(last.next, RankSeason(year: 2027, quarter: 1))
        XCTAssertEqual(last.endDate(calendar: Self.seoul), Self.date(2027, 1, 1, Self.seoul))
    }

    /// 한 시즌이 끝나는 순간은 다음 시즌이 시작하는 순간이다 — 틈도 겹침도 없다.
    func testSeasonsTileTheYearWithoutGaps() {
        for quarter in 1...4 {
            let season = RankSeason(year: 2026, quarter: quarter)
            XCTAssertEqual(
                season.endDate(calendar: Self.seoul),
                season.next.startDate(calendar: Self.seoul)
            )
        }
    }

    func testDaysRemainingCountsDownToTheReset() {
        let season = RankSeason(year: 2026, quarter: 1)
        XCTAssertEqual(season.daysRemaining(from: Self.date(2026, 3, 30, Self.seoul), calendar: Self.seoul), 2)
        XCTAssertEqual(season.daysRemaining(from: Self.date(2026, 3, 31, Self.seoul), calendar: Self.seoul), 1)
        XCTAssertEqual(season.daysRemaining(from: Self.date(2026, 4, 1, Self.seoul), calendar: Self.seoul), 0)
    }

    private static let seoul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
