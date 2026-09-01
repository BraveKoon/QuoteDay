import XCTest
@testable import QuoteDay

/// 반복 규칙의 회차 계산 검증.
///
/// 반복 일정은 저장된 행이 한 건뿐이라, 화면·알림·위젯이 보는 모든 값이
/// 이 계산에서 나온다. 그래서 경계(종료일, 짧은 달, 주말)를 집중적으로 본다.
final class RecurrenceTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - 기본 동작

    func testNoRepeatYieldsOnlyTheAnchor() {
        let anchor = makeDate(2026, 3, 2, hour: 9)
        let starts = RecurrenceRule.none.occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 31),
            calendar: calendar
        )
        XCTAssertEqual(starts, [anchor])
    }

    func testAnchorOutsideWindowIsNotReturned() {
        let anchor = makeDate(2026, 3, 2, hour: 9)
        let starts = RecurrenceRule.none.occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 4, 1),
            to: makeDate(2026, 4, 30),
            calendar: calendar
        )
        XCTAssertTrue(starts.isEmpty)
    }

    func testDailyFillsEveryDayOfTheWindow() {
        let anchor = makeDate(2026, 3, 2, hour: 9)
        let starts = RecurrenceRule(frequency: .daily).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 8, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 7)
        XCTAssertEqual(starts.first, anchor)
        // 시각은 첫 회차와 같아야 한다.
        for start in starts {
            XCTAssertEqual(calendar.component(.hour, from: start), 9)
        }
    }

    func testWeekdaySkipsSaturdayAndSunday() {
        // 2026-03-02 는 월요일.
        let anchor = makeDate(2026, 3, 2, hour: 8)
        let starts = RecurrenceRule(frequency: .weekday).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 15, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 10, "2주면 평일은 10일이다.")
        for start in starts {
            let weekday = calendar.component(.weekday, from: start)
            XCTAssertFalse(weekday == 1 || weekday == 7, "주말이 섞이면 안 된다.")
        }
    }

    func testWeeklyKeepsTheSameWeekday() {
        let anchor = makeDate(2026, 3, 3, hour: 19)
        let starts = RecurrenceRule(frequency: .weekly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 31, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 5, "3월에는 화요일이 5번 있다.")
        let anchorWeekday = calendar.component(.weekday, from: anchor)
        for start in starts {
            XCTAssertEqual(calendar.component(.weekday, from: start), anchorWeekday)
        }
    }

    func testBiweeklyStepsTwoWeeks() {
        let anchor = makeDate(2026, 3, 3, hour: 19)
        let starts = RecurrenceRule(frequency: .biweekly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 4, 30, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.map { calendar.component(.day, from: $0) }, [3, 17, 31, 14, 28])
    }

    func testMonthlyRepeatsOnTheSameDay() {
        let anchor = makeDate(2026, 1, 15, hour: 7)
        let starts = RecurrenceRule(frequency: .monthly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 1, 1),
            to: makeDate(2026, 12, 31, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 12)
        for start in starts {
            XCTAssertEqual(calendar.component(.day, from: start), 15)
        }
    }

    func testMonthlyFromTheThirtyFirstFallsBackInsideShortMonths() {
        let anchor = makeDate(2026, 1, 31, hour: 7)
        let starts = RecurrenceRule(frequency: .monthly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 1, 1),
            to: makeDate(2026, 4, 30, hour: 23, minute: 59),
            calendar: calendar
        )
        let days = starts.map { calendar.component(.day, from: $0) }
        // 2월은 28일까지지만, 다음 달은 다시 31일로 돌아와야 한다(직전 회차 기준으로 밀리면 안 된다).
        XCTAssertEqual(days, [31, 28, 31, 30])
    }

    func testYearlyRepeatsOnTheSameDate() {
        let anchor = makeDate(2026, 5, 5, hour: 12)
        let starts = RecurrenceRule(frequency: .yearly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 1, 1),
            to: makeDate(2029, 12, 31, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 4)
        XCTAssertEqual(starts.map { calendar.component(.year, from: $0) }, [2026, 2027, 2028, 2029])
    }

    // MARK: - 종료일

    func testRepeatStopsAtTheEndDateInclusive() {
        let anchor = makeDate(2026, 3, 2, hour: 9)
        let rule = RecurrenceRule(frequency: .daily, endDate: makeDate(2026, 3, 5))
        let starts = rule.occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 31),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 4, "종료일 당일까지 포함한다.")
        XCTAssertEqual(calendar.component(.day, from: starts.last ?? anchor), 5)
    }

    func testEndDateIsDroppedWhenNotRepeating() {
        let rule = RecurrenceRule(frequency: .none, endDate: makeDate(2026, 3, 5))
        XCTAssertNil(rule.endDate, "반복하지 않는 일정에는 종료일을 남기지 않는다.")
    }

    // MARK: - 오래된 일정

    func testOldAnchorStillResolvesInsideAFarWindow() {
        // 2년 전에 시작한 매일 반복도 창 안의 회차를 정확히 만들어야 한다.
        let anchor = makeDate(2024, 1, 1, hour: 6, minute: 30)
        let starts = RecurrenceRule(frequency: .daily).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 6, 10),
            to: makeDate(2026, 6, 12, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 3)
        XCTAssertEqual(calendar.component(.hour, from: starts[0]), 6)
        XCTAssertEqual(calendar.component(.minute, from: starts[0]), 30)
        XCTAssertEqual(calendar.component(.day, from: starts[0]), 10)
    }

    func testOldAnchorDoesNotSkipWeeklyOccurrences() {
        let anchor = makeDate(2024, 1, 2, hour: 20)
        let starts = RecurrenceRule(frequency: .weekly).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 6, 1),
            to: makeDate(2026, 6, 30, hour: 23, minute: 59),
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 5, "6월에는 화요일이 5번 있다.")
        for start in starts {
            XCTAssertEqual(
                calendar.component(.weekday, from: start),
                calendar.component(.weekday, from: anchor)
            )
        }
    }

    func testLimitStopsGeneration() {
        let anchor = makeDate(2026, 3, 2, hour: 9)
        let starts = RecurrenceRule(frequency: .daily).occurrenceStarts(
            anchor: anchor,
            from: makeDate(2026, 3, 1),
            to: makeDate(2027, 3, 1),
            limit: 3,
            calendar: calendar
        )
        XCTAssertEqual(starts.count, 3)
    }

    // MARK: - 일정에 연결

    func testItemOccursOnLaterRepeatDays() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(
            title: "아침 러닝",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            category: .exercise,
            recurrence: RecurrenceRule(frequency: .weekly)
        )

        XCTAssertTrue(item.occurs(on: makeDate(2026, 3, 9), calendar: calendar))
        XCTAssertFalse(item.occurs(on: makeDate(2026, 3, 10), calendar: calendar))
    }

    func testOccurrenceKeepsTheOriginalDuration() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(
            title: "회의",
            startDate: start,
            endDate: start.addingTimeInterval(5400),
            category: .work,
            recurrence: RecurrenceRule(frequency: .daily)
        )

        let occurrence = item.occurrence(on: makeDate(2026, 3, 5), calendar: calendar)
        XCTAssertEqual(occurrence?.duration, 5400)
        XCTAssertEqual(occurrence.map { calendar.component(.hour, from: $0.start) }, 9)
    }

    func testNextOccurrenceLooksPastTheOriginalStart() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(
            title: "스트레칭",
            startDate: start,
            endDate: start,
            category: .exercise,
            recurrence: RecurrenceRule(frequency: .daily)
        )

        let next = item.nextOccurrence(after: makeDate(2026, 3, 10, hour: 12), calendar: calendar)
        XCTAssertEqual(next.map { calendar.component(.day, from: $0.start) }, 11)
    }

    func testNonRepeatingItemHasNoNextOccurrenceInThePast() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(title: "치과", startDate: start, endDate: start, category: .etc)
        XCTAssertNil(item.nextOccurrence(after: makeDate(2026, 3, 3), calendar: calendar))
    }

    func testOccurrenceNotificationIdentifiersAreUnique() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(
            title: "물 마시기",
            startDate: start,
            endDate: start,
            category: .daily,
            recurrence: RecurrenceRule(frequency: .daily)
        )

        let occurrences = item.occurrences(
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 6),
            calendar: calendar
        )
        let identifiers = Set(occurrences.map(\.notificationIdentifier))
        XCTAssertEqual(identifiers.count, occurrences.count)
        for identifier in identifiers {
            XCTAssertTrue(identifier.hasPrefix(item.notificationIdentifier))
        }
    }

    func testNonRepeatingItemKeepsTheLegacyNotificationIdentifier() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(title: "치과", startDate: start, endDate: start, category: .etc)
        XCTAssertEqual(item.firstOccurrence.notificationIdentifier, item.notificationIdentifier)
    }

    func testStoredFrequencyDegradesToNoRepeat() {
        let start = makeDate(2026, 3, 2, hour: 9)
        let item = ScheduleItem(title: "회의", startDate: start, endDate: start, category: .work)
        item.recurrenceRaw = "미래버전에서추가된주기"
        XCTAssertFalse(item.isRecurring, "모르는 주기 때문에 크래시하면 안 된다.")
    }

    // MARK: - 검증 규칙

    func testValidatorRejectsRepeatEndBeforeStart() {
        let start = makeDate(2026, 3, 10, hour: 9)
        let failure = ScheduleValidator.validate(
            title: "운동",
            start: start,
            end: start,
            recurrence: RecurrenceRule(frequency: .weekly, endDate: makeDate(2026, 3, 1)),
            calendar: calendar
        )
        XCTAssertEqual(failure, .recurrenceEndBeforeStart)
    }

    func testValidatorAcceptsRepeatEndOnTheStartDay() {
        let start = makeDate(2026, 3, 10, hour: 9)
        XCTAssertNil(
            ScheduleValidator.validate(
                title: "운동",
                start: start,
                end: start,
                recurrence: RecurrenceRule(frequency: .weekly, endDate: makeDate(2026, 3, 10, hour: 1)),
                calendar: calendar
            )
        )
    }

    // MARK: - 설명 문구

    func testSummaryMentionsFrequencyAndEnd() {
        let anchor = makeDate(2026, 3, 3, hour: 19)
        let rule = RecurrenceRule(frequency: .weekly, endDate: makeDate(2026, 4, 30))
        let summary = rule.summary(anchor: anchor, calendar: calendar)
        XCTAssertTrue(summary.contains("매주"))
        XCTAssertTrue(summary.contains("까지"))
        XCTAssertEqual(RecurrenceRule.none.summary(anchor: anchor, calendar: calendar), "반복 안 함")
    }

    // MARK: - 도우미

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .now
    }
}
