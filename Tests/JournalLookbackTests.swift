import XCTest
@testable import QuoteDay

/// "그때의 나"와 월간 회고의 셈.
///
/// 둘 다 **없을 때가 많은** 기능이다. 기록이 0편·1편인 사람에게도 화면이
/// 자연스러워야 하고, 빈 카드로 자리를 채우면 안 된다.
final class JournalLookbackTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func note(
        _ dayKey: String,
        text: String = "글",
        slug: String = "slug",
        author: String = "세네카",
        mood: String? = nil
    ) -> ArchivedNote {
        let at = Date.fromDayKey(dayKey, calendar: calendar) ?? .now
        return ArchivedNote(
            id: UUID(),
            dayKey: dayKey,
            quoteSlug: slug,
            quoteText: "원문",
            authorName: author,
            mood: mood,
            source: .daily,
            text: text,
            createdAt: at,
            updatedAt: at
        )
    }

    private func day(_ value: String) -> Date {
        Date.fromDayKey(value, calendar: calendar) ?? .now
    }

    // MARK: - 그때의 나

    func testNothingToLookBackOnGivesNothing() {
        XCTAssertNil(JournalRepository.throwback(in: [], on: day("2026-06-15"), calendar: calendar))
    }

    /// 오늘 쓴 글이 "그때의 나"로 올라오면 우습다.
    func testTodaysOwnEntryIsNotAThrowback() {
        let notes = [note("2026-06-15")]
        XCTAssertNil(
            JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        )
    }

    /// 어제 쓴 글도 "그때의 나"가 아니다.
    func testYesterdayIsNotAThrowback() {
        let notes = [note("2026-06-14")]
        XCTAssertNil(
            JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        )
    }

    func testOneYearAgoTodayIsFound() {
        let notes = [note("2025-06-15", text: "작년의 나")]
        let found = JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(found?.note.text, "작년의 나")
        XCTAssertEqual(found?.monthsAgo, 12)
        XCTAssertEqual(found?.headline, "1년 전 오늘, 이렇게 적었어요")
    }

    /// **먼 쪽이 이긴다.** 1년 전 글이 1개월 전 글보다 훨씬 크게 와닿는다.
    func testTheOlderMemoryWins() {
        let notes = [
            note("2026-05-15", text: "한 달 전"),
            note("2025-06-15", text: "1년 전")
        ]
        let found = JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(found?.note.text, "1년 전")
    }

    func testThreeMonthsAgoIsFoundWhenNothingOlderExists() {
        let notes = [note("2026-03-15", text: "석 달 전")]
        let found = JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(found?.monthsAgo, 3)
        XCTAssertEqual(found?.headline, "3개월 전 오늘, 이렇게 적었어요")
    }

    /// 딱 맞는 날이 없으면 가장 오래된 글을 보여 주되, 한 달은 지난 것이어야 한다.
    func testFallsBackToTheOldestEntryThatIsOldEnough() {
        let notes = [
            note("2026-06-10", text: "며칠 전"),
            note("2026-01-07", text: "가장 오래된 글")
        ]
        let found = JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(found?.note.text, "가장 오래된 글")
    }

    /// 전부 최근 글이면 보여 줄 것이 없다.
    func testRecentEntriesOnlyGiveNothing() {
        let notes = [note("2026-06-10"), note("2026-06-12"), note("2026-06-14")]
        XCTAssertNil(
            JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        )
    }

    func testTwoYearsReadsAsYears() {
        let notes = [note("2024-06-15")]
        let found = JournalRepository.throwback(in: notes, on: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(found?.headline, "2년 전 오늘, 이렇게 적었어요")
    }

    // MARK: - 월간 회고

    func testAnEmptyMonthIsNotWorthShowing() {
        let review = MonthlyReview.make(from: [], month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.noteCount, 0)
        XCTAssertFalse(review.isWorthShowing)
        XCTAssertNil(review.longestNote)
        XCTAssertNil(review.topAuthor)
    }

    /// **빈 회고는 안 만드는 것만 못하다.** 한 편 가지고 "이번 달의 나"를
    /// 보여 주면 그 화면이 사용자를 민망하게 만든다.
    func testOneEntryIsNotEnough() {
        let review = MonthlyReview.make(
            from: [note("2026-06-03")], month: day("2026-06-15"), calendar: calendar
        )
        XCTAssertEqual(review.noteCount, 1)
        XCTAssertFalse(review.isWorthShowing)
    }

    func testThreeEntriesOpenTheReview() {
        let notes = ["2026-06-01", "2026-06-02", "2026-06-03"].map { note($0) }
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertTrue(review.isWorthShowing)
        XCTAssertEqual(review.recordedDays, 3)
    }

    /// 다른 달의 글이 섞이면 안 된다. 달 경계가 이 집계의 급소다.
    func testOtherMonthsAreExcluded() {
        let notes = [
            note("2026-05-31", text: "지난달 마지막 날"),
            note("2026-06-01", text: "이번 달 첫날"),
            note("2026-06-30", text: "이번 달 마지막 날"),
            note("2026-07-01", text: "다음 달 첫날")
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.noteCount, 2)
        XCTAssertEqual(review.firstNote?.text, "이번 달 첫날")
        XCTAssertEqual(review.lastNote?.text, "이번 달 마지막 날")
    }

    /// 하루에 세 편을 써도 하루다.
    func testRecordedDaysCountsDaysNotEntries() {
        let notes = [
            note("2026-06-01", slug: "a"),
            note("2026-06-01", slug: "b"),
            note("2026-06-02", slug: "c")
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.noteCount, 3)
        XCTAssertEqual(review.recordedDays, 2)
    }

    func testTheLongestEntryIsTheHighlight() {
        let notes = [
            note("2026-06-01", text: "짧게"),
            note("2026-06-02", text: String(repeating: "가", count: 200)),
            note("2026-06-03", text: "보통 길이로 적은 글")
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.longestNote?.text.count, 200)
    }

    /// 줄바꿈만 잔뜩 넣은 글이 "가장 길게 쓴 날"을 가져가면 안 된다.
    func testWhitespaceDoesNotWinTheLongestEntry() {
        let notes = [
            note("2026-06-01", text: "\n\n\n\n\n\n\n\n짧다"),
            note("2026-06-02", text: "이쪽이 실제로 더 길게 쓴 글이다"),
            note("2026-06-03", text: "셋")
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.longestNote?.text, "이쪽이 실제로 더 길게 쓴 글이다")
    }

    func testTopAuthorIsTheMostFrequent() {
        let notes = [
            note("2026-06-01", author: "세네카"),
            note("2026-06-02", author: "세네카"),
            note("2026-06-03", author: "처칠")
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.topAuthor, "세네카")
    }

    /// 같은 수가 여럿이어도 **답이 하나로 정해져야** 한다. 열 때마다 달라지면
    /// 회고가 아니다.
    func testTiesResolveTheSameWayEveryTime() {
        let notes = [
            note("2026-06-01", author: "처칠"),
            note("2026-06-02", author: "세네카"),
            note("2026-06-03", author: "간디")
        ]
        let first = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        let second = MonthlyReview.make(
            from: notes.reversed(), month: day("2026-06-15"), calendar: calendar
        )
        XCTAssertEqual(first.topAuthor, second.topAuthor)
    }

    func testTopMoodIsCounted() {
        let notes = [
            note("2026-06-01", mood: QuoteMood.tired.rawValue),
            note("2026-06-02", mood: QuoteMood.tired.rawValue),
            note("2026-06-03", mood: QuoteMood.joyful.rawValue)
        ]
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.topMood, QuoteMood.tired.rawValue)
    }

    func testMoodIsNilWhenNobodyChoseOne() {
        let notes = ["2026-06-01", "2026-06-02", "2026-06-03"].map { note($0) }
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertNil(review.topMood)
    }

    func testHeadlineReadsNaturally() {
        let notes = ["2026-06-01", "2026-06-01", "2026-06-02", "2026-06-03"].map { note($0, slug: UUID().uuidString) }
        let review = MonthlyReview.make(from: notes, month: day("2026-06-15"), calendar: calendar)
        XCTAssertEqual(review.headline, "3일 동안 4편을 남겼어요")
    }

    func testPreviousMonthIsTheMonthBefore() {
        let previous = MonthlyReview.previousMonth(from: day("2026-01-15"), calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: previous)
        XCTAssertEqual(parts.year, 2025)
        XCTAssertEqual(parts.month, 12)
        XCTAssertEqual(parts.day, 1)
    }

    func testReviewableMonthsAreNewestFirst() {
        let notes = [note("2026-01-05"), note("2026-03-05"), note("2026-03-20"), note("2026-02-01")]
        let months = JournalRepository.reviewableMonths(in: notes, calendar: calendar)
        XCTAssertEqual(months.count, 3)
        let first = calendar.dateComponents([.month], from: months[0]).month
        XCTAssertEqual(first, 3)
    }
}
