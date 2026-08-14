import SwiftData
import XCTest
@testable import QuoteDay

/// 일정 모델, 캘린더 계산, 딥링크, 위젯 스냅샷 검증.
final class ScheduleAndNavigationTests: XCTestCase {

    // MARK: - 일정 모델

    func testEndDateIsClampedToStart() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let item = ScheduleItem(
            title: "잘못된 일정",
            startDate: start,
            endDate: start.addingTimeInterval(-3600),
            category: .work
        )
        XCTAssertEqual(item.endDate, start, "종료가 시작보다 빠르면 시작 시각으로 맞춰야 한다.")
    }

    func testDisplayTitleFallsBackToCategory() {
        let item = ScheduleItem(
            title: "   ",
            startDate: .now,
            endDate: .now,
            category: .meal
        )
        XCTAssertEqual(item.displayTitle, AppCategory.meal.title)
    }

    func testUnknownCategoryRawValueDegradesToEtc() {
        let item = ScheduleItem(title: "테스트", startDate: .now, endDate: .now, category: .work)
        item.categoryRaw = "미래버전에서추가된카테고리"
        XCTAssertEqual(item.category, .etc, "모르는 카테고리 때문에 크래시하면 안 된다.")
    }

    func testResolvedQuoteIsStableAndFollowsCategory() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let item = ScheduleItem(title: "수학 공부", startDate: start, endDate: start, category: .study)

        let first = item.resolvedQuote()
        let second = item.resolvedQuote()
        XCTAssertEqual(first.slug, second.slug)

        let pool = QuoteService.shared.candidatePool(for: .study)
        XCTAssertTrue(pool.contains { $0.slug == first.slug })
    }

    func testExplicitQuoteSlugWins() {
        let item = ScheduleItem(
            title: "저녁",
            startDate: .now,
            endDate: .now,
            category: .meal,
            quoteSlug: "cicero-hunger-is-the-best-sauce"
        )
        XCTAssertEqual(item.resolvedQuote().slug, "cicero-hunger-is-the-best-sauce")
    }

    func testInvalidQuoteSlugFallsBackInsteadOfCrashing() {
        let item = ScheduleItem(
            title: "저녁",
            startDate: .now,
            endDate: .now,
            category: .meal,
            quoteSlug: "삭제된-슬러그"
        )
        XCTAssertFalse(item.resolvedQuote().slug.isEmpty)
    }

    func testNotificationIdentifierIsDerivedFromID() {
        let item = ScheduleItem(title: "회의", startDate: .now, endDate: .now, category: .work)
        XCTAssertEqual(item.notificationIdentifier, "schedule-\(item.id.uuidString)")
    }

    // MARK: - 검증 규칙

    func testValidatorRejectsEmptyTitle() {
        let now = Date.now
        XCTAssertEqual(ScheduleValidator.validate(title: "  ", start: now, end: now), .emptyTitle)
    }

    func testValidatorRejectsEndBeforeStart() {
        let now = Date.now
        XCTAssertEqual(
            ScheduleValidator.validate(title: "운동", start: now, end: now.addingTimeInterval(-60)),
            .endBeforeStart
        )
    }

    func testValidatorAcceptsValidInput() {
        let now = Date.now
        XCTAssertNil(
            ScheduleValidator.validate(title: "운동", start: now, end: now.addingTimeInterval(3600))
        )
    }

    // MARK: - SwiftData 저장

    @MainActor
    func testInsertAndFetchRoundTrips() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = container.mainContext

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(ScheduleItem(title: "러닝", startDate: start, endDate: start, category: .exercise))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ScheduleItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "러닝")
        XCTAssertEqual(fetched.first?.category, .exercise)
    }

    // MARK: - 캘린더 계산

    @MainActor
    func testMonthGridAlwaysHasFortyTwoDays() {
        let viewModel = CalendarViewModel(referenceDate: makeDate(2026, 2, 15))
        XCTAssertEqual(viewModel.days.count, 42)
    }

    @MainActor
    func testMonthGridContainsEveryDayOfTheMonth() {
        let calendar = Calendar.current
        let reference = makeDate(2026, 2, 15)
        let viewModel = CalendarViewModel(referenceDate: reference)

        let inMonth = viewModel.days.filter(\.isInDisplayedMonth)
        let expected = calendar.range(of: .day, in: .month, for: reference)?.count
        XCTAssertEqual(inMonth.count, expected)
    }

    @MainActor
    func testWeekdaySymbolsHaveSevenEntries() {
        let viewModel = CalendarViewModel(referenceDate: .now)
        XCTAssertEqual(viewModel.weekdaySymbols.count, 7)
    }

    @MainActor
    func testMonthNavigationMovesByOneMonth() {
        let calendar = Calendar.current
        let viewModel = CalendarViewModel(referenceDate: makeDate(2026, 12, 10))
        let original = viewModel.displayedMonth

        viewModel.goToNextMonth()
        XCTAssertEqual(calendar.component(.year, from: viewModel.displayedMonth), 2027)
        XCTAssertEqual(calendar.component(.month, from: viewModel.displayedMonth), 1)

        viewModel.goToPreviousMonth()
        XCTAssertEqual(viewModel.displayedMonth, original)
    }

    @MainActor
    func testSelectingDayFromAnotherMonthFollowsThatMonth() {
        let viewModel = CalendarViewModel(referenceDate: makeDate(2026, 6, 15))
        viewModel.select(makeDate(2026, 7, 3))
        XCTAssertEqual(Calendar.current.component(.month, from: viewModel.displayedMonth), 7)
        XCTAssertTrue(viewModel.isSelected(makeDate(2026, 7, 3)))
    }

    // MARK: - 딥링크

    func testQuoteDeepLinkRoundTrips() {
        let id = UUID()
        let url = DeepLink.quote(id).url
        XCTAssertEqual(DeepLink(url: url), .quote(id))
    }

    func testScheduleDeepLinkRoundTrips() {
        let id = UUID()
        XCTAssertEqual(DeepLink(url: DeepLink.schedule(id).url), .schedule(id))
    }

    func testTodayDeepLink() {
        XCTAssertEqual(DeepLink(url: URL(string: "quoteday://today")!), .today)
    }

    func testForeignSchemeIsRejected() {
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com/quote/1")!))
    }

    func testMalformedUUIDIsRejected() {
        XCTAssertNil(DeepLink(url: URL(string: "quoteday://quote/not-a-uuid")!))
    }

    // MARK: - 위젯 스냅샷

    func testSnapshotEncodesAndDecodes() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = WidgetSnapshot(
            generatedAt: start,
            schedules: [
                ScheduleSnapshot(
                    id: UUID(),
                    title: "수학 공부",
                    start: start,
                    end: start.addingTimeInterval(3600),
                    category: .study
                )
            ]
        )

        let data = try JSONEncoder.quoteDay.encode(snapshot)
        let decoded = try JSONDecoder.quoteDay.decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded.schedules.first?.title, "수학 공부")
        XCTAssertEqual(decoded.schedules.first?.category, .study)
    }

    func testSnapshotNextScheduleSkipsPastEntries() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = ScheduleSnapshot(
            id: UUID(), title: "지난 일정",
            start: now.addingTimeInterval(-3600), end: now, category: .work
        )
        let future = ScheduleSnapshot(
            id: UUID(), title: "다가올 일정",
            start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), category: .meal
        )
        let snapshot = WidgetSnapshot(generatedAt: now, schedules: [future, past])

        XCTAssertEqual(snapshot.nextSchedule(after: now)?.title, "다가올 일정")
    }

    func testSnapshotFiltersByDay() {
        let calendar = Calendar.current
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let snapshot = WidgetSnapshot(schedules: [
            ScheduleSnapshot(id: UUID(), title: "오늘", start: today, end: today, category: .daily),
            ScheduleSnapshot(id: UUID(), title: "내일", start: tomorrow, end: tomorrow, category: .daily)
        ])

        XCTAssertEqual(snapshot.schedules(on: today).map(\.title), ["오늘"])
    }

    func testEmptySnapshotIsSafeToRead() {
        XCTAssertTrue(WidgetSnapshot.empty.schedules(on: .now).isEmpty)
        XCTAssertNil(WidgetSnapshot.empty.nextSchedule())
    }

    // MARK: - 포매터

    func testCountdownReturnsNilForPastDates() {
        XCTAssertNil(Formatters.countdown(to: Date.now.addingTimeInterval(-60)))
    }

    func testCountdownFormatsHoursAndMinutes() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(Formatters.countdown(to: now.addingTimeInterval(90 * 60), from: now), "1시간 30분 후")
        XCTAssertEqual(Formatters.countdown(to: now.addingTimeInterval(30 * 60), from: now), "30분 후")
        XCTAssertEqual(Formatters.countdown(to: now.addingTimeInterval(2 * 3600), from: now), "2시간 후")
    }

    // MARK: - 카테고리

    func testEveryCategoryHasEmojiTitleAndFallback() {
        for category in AppCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty)
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.notificationLead.isEmpty)
            XCTAssertFalse(category.related.isEmpty, "\(category.title) 에 폴백 카테고리가 없다.")
            XCTAssertFalse(category.related.contains(category), "자기 자신을 폴백으로 두면 안 된다.")
        }
    }

    func testCategoryStoredValueInitIsSafe() {
        XCTAssertEqual(AppCategory(storedValue: nil), .etc)
        XCTAssertEqual(AppCategory(storedValue: "study"), .study)
    }

    // MARK: - 도우미

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components) ?? .now
    }
}
