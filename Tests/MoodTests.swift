import XCTest
@testable import QuoteDay

/// 기분으로 고르기.
///
/// "AI 추천"의 자리를 대신하는 기능이라, AI 가 못 하는 두 가지를 반드시
/// 해내야 한다 — **결정적일 것**과 **틀린 문장을 내놓지 않을 것**.
final class MoodTests: XCTestCase {

    private let service = QuoteService.shared

    /// 모든 기분에 고를 문장이 있어야 한다. 하나라도 비면 칩을 눌렀을 때
    /// 아무 일도 일어나지 않는다.
    func testEveryMoodHasQuotes() {
        for mood in QuoteMood.allCases {
            XCTAssertFalse(
                MoodLibrary.slugs(for: mood).isEmpty,
                "\(mood.title) 에 붙은 명언이 없습니다."
            )
        }
    }

    /// 한 번 쓰고 마는 기능이 되지 않으려면 어느 정도 모여 있어야 한다.
    func testEveryMoodHasEnoughVariety() {
        for mood in QuoteMood.allCases {
            XCTAssertGreaterThanOrEqual(
                MoodLibrary.slugs(for: mood).count, 12,
                "\(mood.title) 의 명언이 너무 적습니다."
            )
        }
    }

    /// 꼬리표가 가리키는 명언이 전부 실재해야 한다.
    func testEveryTaggedSlugExists() {
        for slug in MoodLibrary.bySlug.keys {
            XCTAssertNotNil(service.quote(slug: slug), "없는 명언을 가리킵니다: \(slug)")
        }
    }

    /// 한 명언에 기분은 최대 두 개. 셋 넷 붙이면 아무 뜻도 없어진다.
    func testNoQuoteCarriesMoreThanTwoMoods() {
        for (slug, moods) in MoodLibrary.bySlug {
            XCTAssertLessThanOrEqual(moods.count, 2, "\(slug) 에 기분이 너무 많습니다.")
            XCTAssertEqual(Set(moods).count, moods.count, "\(slug) 에 같은 기분이 두 번 붙었습니다.")
        }
    }

    /// **애매하면 붙이지 않는다.** 201편이 전부 태그되어 있다면 그건 판단을
    /// 하지 않고 기계적으로 채웠다는 뜻이다.
    func testSomeQuotesAreDeliberatelyLeftUntagged() {
        XCTAssertLessThan(
            MoodLibrary.bySlug.count, service.allQuotes.count,
            "모든 명언에 기분이 붙어 있습니다. 애매한 것은 비워 두어야 합니다."
        )
    }

    // MARK: - 고르기

    /// 같은 날 같은 기분이면 **항상 같은 문장**이다. 누를 때마다 바뀌면
    /// 고르는 행위가 뽑기가 되고, 좋았던 문장을 다시 찾을 수 없다.
    func testTheSameMoodOnTheSameDayGivesTheSameQuote() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        for mood in QuoteMood.allCases {
            let first = service.presentation(for: mood, on: date)
            let second = service.presentation(for: mood, on: date)
            XCTAssertEqual(first?.quote.slug, second?.quote.slug, "\(mood.title) 이 뽑기가 되었습니다.")
        }
    }

    /// 고른 기분의 문장이 실제로 그 기분에 붙어 있어야 한다.
    func testTheChosenQuoteActuallyCarriesThatMood() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        for mood in QuoteMood.allCases {
            guard let presentation = service.presentation(for: mood, on: date) else {
                XCTFail("\(mood.title) 에서 아무것도 나오지 않았습니다.")
                continue
            }
            let tags = MoodLibrary.bySlug[presentation.quote.slug] ?? []
            XCTAssertTrue(tags.contains(mood), "\(mood.title) 과 상관없는 문장이 나왔습니다.")
        }
    }

    /// 날이 바뀌면 문장도 바뀐다 — 한 기분을 계속 고르는 사람에게 같은
    /// 문장만 보이면 안 된다.
    func testTheQuoteMovesAcrossDays() {
        let calendar = Calendar.current
        var seen: Set<String> = []
        var day = Date(timeIntervalSince1970: 1_800_000_000)

        for _ in 0..<10 {
            if let slug = service.presentation(for: .tired, on: day)?.quote.slug {
                seen.insert(slug)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        XCTAssertGreaterThan(seen.count, 1, "열흘 내내 같은 문장만 나옵니다.")
    }

    // MARK: - 보여 주는 말

    func testEveryMoodHasWordsToShow() {
        for mood in QuoteMood.allCases {
            XCTAssertFalse(mood.title.isEmpty)
            XCTAssertFalse(mood.emoji.isEmpty)
            XCTAssertFalse(mood.invitation.isEmpty)
        }
    }
}
