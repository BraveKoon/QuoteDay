import XCTest
@testable import QuoteDay

/// 알림에서 바로 기록으로 가는 길과, 매일 다른 말 걸기.
@MainActor
final class JournalComposeTests: XCTestCase {

    // MARK: - 딥링크

    func testComposeLinkRoundTrips() {
        let url = DeepLink.composeToday.url
        XCTAssertEqual(DeepLink(url: url), .composeToday)
    }

    /// 쿼리가 없으면 그냥 홈이다. 기존 위젯 링크가 입력칸을 열어 버리면 안 된다.
    func testPlainTodayStaysPlain() throws {
        let url = try XCTUnwrap(URL(string: "quoteday://today"))
        XCTAssertEqual(DeepLink(url: url), .today)
    }

    func testOtherComposeValuesAreIgnored() throws {
        let url = try XCTUnwrap(URL(string: "quoteday://today?compose=0"))
        XCTAssertEqual(DeepLink(url: url), .today)
    }

    func testComposeLinkRaisesTheFlagOnTheRouter() {
        let router = AppRouter()
        XCTAssertFalse(router.wantsTodayCompose)

        router.handle(.composeToday)

        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertTrue(router.wantsTodayCompose)
    }

    /// 알림의 동작 이름이 바뀌면 조용히 동작하지 않게 된다.
    func testNotificationCategoryCarriesTheComposeAction() {
        let category = DailyQuoteNotification.category
        XCTAssertEqual(category.identifier, DailyQuoteNotification.categoryIdentifier)
        XCTAssertEqual(
            category.actions.map(\.identifier),
            [DailyQuoteNotification.composeActionIdentifier]
        )
    }

    // MARK: - 말 걸기

    /// 같은 물음이 매일 똑같이 오면 벽지가 된다. 요일마다 달라야 한다.
    func testPromptChangesThroughTheWeek() {
        let calendar = Calendar.current
        var seen: Set<String> = []
        var day = Date(timeIntervalSince1970: 1_800_000_000)

        for _ in 0..<7 {
            seen.insert(JournalCard.prompt(for: day, calendar: calendar))
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        XCTAssertEqual(seen.count, 7, "한 주 안에 같은 문구가 두 번 나옵니다.")
    }

    /// 같은 요일이면 같은 문구. 하루 안에 문구가 흔들리면 안 된다.
    func testPromptIsStableWithinADay() {
        let calendar = Calendar.current
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let evening = calendar.date(byAdding: .hour, value: 11, to: morning) ?? morning
        XCTAssertEqual(
            JournalCard.prompt(for: morning, calendar: calendar),
            JournalCard.prompt(for: evening, calendar: calendar)
        )
    }
}
