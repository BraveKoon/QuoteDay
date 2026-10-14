import XCTest
@testable import QuoteDay

/// 연속 기록의 날짜 셈.
///
/// 스트릭은 코드가 짧은 대신 **날짜 경계에서 조용히 틀린다.** 틀리면 사용자가
/// 가장 아끼는 숫자가 틀리는 것이고, 그건 기능이 없느니만 못하다.
final class JournalStreakTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ value: String) -> Date {
        Date.fromDayKey(value, calendar: calendar) ?? .now
    }

    private func record(_ streak: JournalStreak, _ value: String) -> JournalStreak {
        JournalStreakRules.recording(streak, on: day(value), calendar: calendar)
    }

    // MARK: - 이어 가기

    func testFirstEntryStartsAtOne() {
        let streak = record(JournalStreak(), "2026-03-01")
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.longest, 1)
        XCTAssertEqual(streak.totalDays, 1)
    }

    func testConsecutiveDaysAddUp() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-03-03"] {
            streak = record(streak, value)
        }
        XCTAssertEqual(streak.current, 3)
        XCTAssertEqual(streak.longest, 3)
        XCTAssertEqual(streak.totalDays, 3)
    }

    /// 하루에 글을 세 편 써도 하루다.
    func testWritingSeveralTimesInOneDayCountsOnce() {
        var streak = record(JournalStreak(), "2026-03-01")
        streak = record(streak, "2026-03-01")
        streak = record(streak, "2026-03-01")
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.totalDays, 1)
    }

    /// 달이 바뀌는 자리에서 끊기면 안 된다.
    func testTheStreakSurvivesTheEndOfAMonth() {
        var streak = record(JournalStreak(), "2026-01-31")
        streak = record(streak, "2026-02-01")
        XCTAssertEqual(streak.current, 2)
    }

    /// 해가 바뀌는 자리도 마찬가지다.
    func testTheStreakSurvivesTheEndOfAYear() {
        var streak = record(JournalStreak(), "2026-12-31")
        streak = record(streak, "2027-01-01")
        XCTAssertEqual(streak.current, 2)
    }

    /// 윤년의 2월 29일.
    func testTheStreakSurvivesALeapDay() {
        var streak = record(JournalStreak(), "2028-02-28")
        streak = record(streak, "2028-02-29")
        streak = record(streak, "2028-03-01")
        XCTAssertEqual(streak.current, 3)
    }

    // MARK: - 유예

    /// 하루 빠져도 끊기지 않는다. 이 한 가지가 "망했으니 그만"을 막는다.
    func testOneMissedDayIsCoveredByAFreeze() {
        // 2026-03-02(월)과 03-04(수)는 같은 주다. 주가 바뀌면 유예가 하나
        // 더 들어와서 무엇을 쟀는지 흐려진다.
        var streak = record(JournalStreak(), "2026-03-02")
        XCTAssertEqual(streak.freezesLeft, 1)

        streak = record(streak, "2026-03-04")

        XCTAssertEqual(streak.current, 2, "유예가 있는데 연속이 끊겼습니다.")
        XCTAssertEqual(streak.freezesLeft, 0)
        XCTAssertTrue(streak.usedFreezeOnLastRecord)
        XCTAssertNotNil(streak.freezeNote)
    }

    /// 유예가 없으면 끊긴다. 끊기는 것 자체를 없애면 연속이라는 말이 뜻을 잃는다.
    func testWithoutAFreezeTheStreakBreaks() {
        var streak = JournalStreak(freezesLeft: 0)
        streak = record(streak, "2026-03-02")
        streak = record(streak, "2026-03-04")

        XCTAssertEqual(streak.current, 1)
        XCTAssertFalse(streak.usedFreezeOnLastRecord)
    }

    /// 유예 하나로 이틀을 메울 수는 없다.
    func testOneFreezeCannotCoverTwoMissedDays() {
        var streak = record(JournalStreak(), "2026-03-02")
        streak = record(streak, "2026-03-05")
        XCTAssertEqual(streak.current, 1)
    }

    func testFreezesAreGrantedWeeklyUpToTheCap() {
        var streak = record(JournalStreak(), "2026-03-02")   // 월요일
        streak.freezesLeft = 0

        streak = JournalStreakRules.granting(streak, on: day("2026-03-09"), calendar: calendar)
        XCTAssertEqual(streak.freezesLeft, 1)

        streak = JournalStreakRules.granting(streak, on: day("2026-03-16"), calendar: calendar)
        XCTAssertEqual(streak.freezesLeft, 2)

        // 상한을 넘기지 않는다.
        streak = JournalStreakRules.granting(streak, on: day("2026-03-23"), calendar: calendar)
        XCTAssertEqual(streak.freezesLeft, JournalStreak.maximumFreezes)
    }

    /// 몇 주를 쉬었든 한 번에 하나만 받는다. 몰아 주면 유예가 쌓여서
    /// 연속 기록이 아무 뜻도 없게 된다.
    func testSkippedWeeksDoNotStackUpFreezes() {
        var streak = JournalStreak(freezesLeft: 0, lastFreezeWeek: "2026-W01")
        streak = JournalStreakRules.granting(streak, on: day("2026-06-01"), calendar: calendar)
        XCTAssertEqual(streak.freezesLeft, 1)
    }

    func testTheSameWeekGrantsNothingTwice() {
        var streak = JournalStreak(freezesLeft: 0)
        streak = JournalStreakRules.granting(streak, on: day("2026-03-02"), calendar: calendar)
        let afterFirst = streak.freezesLeft
        streak = JournalStreakRules.granting(streak, on: day("2026-03-05"), calendar: calendar)
        XCTAssertEqual(streak.freezesLeft, afterFirst)
    }

    // MARK: - 줄지 않는 숫자

    /// **누적은 어떤 경우에도 줄지 않는다.** 실패를 보여 주지 않는 지표를
    /// 항상 하나 둬야 "망했으니 그만"이 안 나온다.
    func testTotalNeverGoesDown() {
        var streak = JournalStreak()
        var total = 0
        for value in ["2026-03-01", "2026-03-02", "2026-03-20", "2026-04-01", "2026-04-02"] {
            streak = record(streak, value)
            XCTAssertGreaterThanOrEqual(streak.totalDays, total)
            total = streak.totalDays
        }
        XCTAssertEqual(streak.totalDays, 5)
    }

    func testLongestRemembersThePeak() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-03-03", "2026-03-20"] {
            streak = record(streak, value)
        }
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.longest, 3)
    }

    /// 끊긴 날에도 실패를 말하지 않는다.
    func testBrokenStreakShowsTheCumulativeCount() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02"] {
            streak = record(streak, value)
        }
        let settled = JournalStreakRules.settled(streak, on: day("2026-03-30"), calendar: calendar)
        XCTAssertEqual(settled.current, 0)
        XCTAssertEqual(settled.homeText, "지금까지 2번 기록했어요")
        XCTAssertFalse(settled.homeText.contains("끝"))
    }

    // MARK: - 보여 주기 전에 맞추기

    /// 사흘 쉬고 앱을 연 사람에게 "5일째"라고 말하면 안 된다.
    func testOpeningTheAppAfterALongGapClearsTheStreak() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-03-03"] {
            streak = record(streak, value)
        }
        let settled = JournalStreakRules.settled(streak, on: day("2026-03-10"), calendar: calendar)
        XCTAssertEqual(settled.current, 0)
    }

    /// 유예로 메울 수 있는 간격이면 아직 끊긴 것이 아니다.
    func testAGapTheFreezeCanStillCoverIsNotBrokenYet() {
        var streak = record(JournalStreak(), "2026-03-02")
        let settled = JournalStreakRules.settled(streak, on: day("2026-03-04"), calendar: calendar)
        XCTAssertEqual(settled.current, 1, "아직 메울 수 있는데 미리 끊었습니다.")

        // 그리고 실제로 쓰면 이어진다.
        streak = JournalStreakRules.recording(settled, on: day("2026-03-04"), calendar: calendar)
        XCTAssertEqual(streak.current, 2)
    }

    func testSettlingDoesNothingBeforeTheFirstEntry() {
        let settled = JournalStreakRules.settled(JournalStreak(), on: day("2026-03-10"), calendar: calendar)
        XCTAssertEqual(settled.current, 0)
        XCTAssertEqual(settled.totalDays, 0)
        XCTAssertTrue(settled.homeText.isEmpty)
    }

    // MARK: - 기기 시계를 되돌렸을 때

    /// 시계를 과거로 돌려도 연속 기록이 망가지면 안 된다.
    func testTurningTheClockBackDoesNotCorruptTheStreak() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-03-03"] {
            streak = record(streak, value)
        }
        let before = streak.lastRecordedDay

        streak = record(streak, "2026-02-10")

        XCTAssertEqual(streak.lastRecordedDay, before, "과거 날짜가 마지막 기록일을 덮었습니다.")
        XCTAssertGreaterThanOrEqual(streak.totalDays, 3)
        XCTAssertEqual(streak.longest, 3)
    }

    /// 되돌린 뒤 정상 날짜로 돌아와도 이어진다.
    func testTheStreakRecoversAfterTheClockComesBack() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-02-10", "2026-03-03"] {
            streak = record(streak, value)
        }
        // 되돌린 날은 연속을 늘리지 않고, 돌아온 뒤 03-03 이 하루를 더한다.
        XCTAssertEqual(streak.current, 3)
    }

    // MARK: - 시간대

    /// 시간대가 바뀌어도 "같은 날"은 그 기기의 하루다.
    func testDayKeyFollowsTheDeviceCalendar() {
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        let streakSeoul = JournalStreakRules.recording(
            JournalStreak(), on: Date(timeIntervalSince1970: 1_800_000_000), calendar: seoul
        )
        let streakNewYork = JournalStreakRules.recording(
            JournalStreak(), on: Date(timeIntervalSince1970: 1_800_000_000), calendar: newYork
        )

        XCTAssertEqual(streakSeoul.current, 1)
        XCTAssertEqual(streakNewYork.current, 1)
        // 같은 순간이라도 기기의 달력이 다르면 날짜 이름은 다를 수 있다.
        XCTAssertFalse(streakSeoul.lastRecordedDay.isEmpty)
        XCTAssertFalse(streakNewYork.lastRecordedDay.isEmpty)
    }

    // MARK: - 보여 주는 말

    func testHomeTextStaysShortAndPositive() {
        var streak = JournalStreak()
        for value in ["2026-03-01", "2026-03-02", "2026-03-03"] {
            streak = record(streak, value)
        }
        XCTAssertEqual(streak.homeText, "3일째 · 지금까지 3번")
    }

    func testNothingIsShownBeforeTheFirstEntry() {
        XCTAssertTrue(JournalStreak().homeText.isEmpty)
        XCTAssertNil(JournalStreak().freezeNote)
    }
}
