import XCTest
@testable import QuoteDay

/// 명언 데이터와 선택 알고리즘 검증.
final class QuoteEngineTests: XCTestCase {

    private let service = QuoteService.shared
    private let library = QuoteLibrary.shared

    // MARK: - 데이터 무결성

    func testLibraryHasAtLeastOneHundredQuotes() {
        XCTAssertGreaterThanOrEqual(library.count, 100, "명언은 최소 100개 이상이어야 한다.")
    }

    func testSlugsAreUnique() {
        let slugs = library.quotes.map(\.slug)
        XCTAssertEqual(Set(slugs).count, slugs.count, "slug 가 중복되면 딥링크가 어긋난다.")
    }

    func testGeneratedIDsAreUnique() {
        let ids = library.quotes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryQuoteHasAKnownAuthor() {
        for quote in library.quotes {
            XCTAssertNotNil(
                AuthorLibrary.byID[quote.authorID],
                "\(quote.slug) 가 알 수 없는 인물 \(quote.authorID) 를 참조한다."
            )
        }
    }

    func testEveryCategoryHasQuotes() {
        for category in AppCategory.selectableForQuotes {
            XCTAssertGreaterThan(
                library.count(in: category), 0,
                "\(category.title) 카테고리에 명언이 없다."
            )
        }
    }

    func testAuthorsHaveBiography() {
        for author in AuthorLibrary.all {
            XCTAssertFalse(author.biography.isEmpty, "\(author.id) 의 소개가 비어 있다.")
            XCTAssertFalse(author.occupation.isEmpty, "\(author.id) 의 직업이 비어 있다.")
        }
    }

    // MARK: - 오늘의 명언

    func testQuoteOfTheDayIsStableWithinTheSameDay() {
        let morning = date(2026, 3, 14, hour: 0, minute: 1)
        let evening = date(2026, 3, 14, hour: 23, minute: 59)

        XCTAssertEqual(
            service.quoteOfTheDay(for: morning).slug,
            service.quoteOfTheDay(for: evening).slug,
            "같은 날에는 몇 번을 열어도 같은 명언이어야 한다."
        )
    }

    func testQuoteOfTheDayIsDeterministicAcrossServiceInstances() {
        let day = date(2026, 7, 1)
        let another = QuoteService()
        XCTAssertEqual(
            service.quoteOfTheDay(for: day).slug,
            another.quoteOfTheDay(for: day).slug,
            "위젯 프로세스와 앱 프로세스가 같은 결과를 내야 한다."
        )
    }

    func testQuoteOfTheDayVariesAcrossDays() {
        let calendar = Calendar.current
        let start = date(2026, 1, 1)
        var slugs = Set<String>()
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            slugs.insert(service.quoteOfTheDay(for: day).slug)
        }
        // 해시 특성상 완전한 순열은 아니지만, 30일이면 충분히 다양해야 한다.
        XCTAssertGreaterThan(slugs.count, 20, "날짜가 바뀌어도 명언이 거의 바뀌지 않는다.")
    }

    func testPreferredCategoryRestrictsQuoteOfTheDay() {
        let day = date(2026, 5, 5)
        let quote = service.quoteOfTheDay(for: day, preferred: .exercise)
        XCTAssertTrue(quote.matches(.exercise))
    }

    // MARK: - 카테고리 선택

    func testCategoryQuoteIsDeterministicForSameSeed() {
        let first = service.quote(for: .study, seed: "abc")
        let second = service.quote(for: .study, seed: "abc")
        XCTAssertEqual(first.slug, second.slug)
    }

    func testStudyScheduleGetsStudyRelatedQuote() {
        let quote = service.quote(for: .study, seed: "math-homework")
        let pool = service.candidatePool(for: .study)
        XCTAssertTrue(pool.contains { $0.slug == quote.slug })
        XCTAssertTrue(
            quote.matches(.study) || quote.matches(.growth) || quote.matches(.work),
            "학업 일정에는 학업 또는 인접 카테고리의 명언이 와야 한다."
        )
    }

    func testCandidatePoolFallsBackToRelatedCategories() {
        // `etc` 는 직접 매칭되는 명언이 없으므로 폴백이 동작해야 한다.
        let pool = service.candidatePool(for: .etc)
        XCTAssertFalse(pool.isEmpty, "폴백이 동작하지 않으면 빈 알림이 나간다.")
        XCTAssertGreaterThanOrEqual(pool.count, QuoteService.minimumPoolSize)
    }

    func testCandidatePoolHasNoDuplicates() {
        for category in AppCategory.allCases {
            let pool = service.candidatePool(for: category)
            XCTAssertEqual(Set(pool.map(\.slug)).count, pool.count, "\(category.title) 폴백에 중복이 있다.")
        }
    }

    func testScheduleQuoteIsStableForSameSchedule() {
        let id = UUID()
        let start = date(2026, 4, 2, hour: 18)
        let first = service.quote(forScheduleID: id, start: start, category: .study)
        let second = service.quote(forScheduleID: id, start: start, category: .study)
        XCTAssertEqual(first.slug, second.slug)
    }

    // MARK: - 조회

    func testLookupByIDRoundTrips() {
        let quote = service.quoteOfTheDay()
        XCTAssertEqual(service.quote(id: quote.id)?.slug, quote.slug)
    }

    func testSearchMatchesAuthorName() {
        let results = service.search("Churchill")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.authorID == "churchill" })
    }

    func testSearchWithEmptyTermReturnsEverything() {
        XCTAssertEqual(service.search("   ").count, library.count)
    }

    func testUnknownAuthorFallsBackToPlaceholder() {
        XCTAssertEqual(AuthorLibrary.author(id: "does-not-exist").id, Author.unknown.id)
    }

    // MARK: - 해시 유틸리티

    func testStableHashIsConsistent() {
        XCTAssertEqual(StableHash.fnv1a("quoteday"), StableHash.fnv1a("quoteday"))
        XCTAssertNotEqual(StableHash.fnv1a("a"), StableHash.fnv1a("b"))
    }

    func testStableHashIndexStaysInRange() {
        for value in 0..<200 {
            let index = StableHash.index(for: "seed-\(value)", count: 7)
            XCTAssertTrue((0..<7).contains(index))
        }
        XCTAssertEqual(StableHash.index(for: "x", count: 0), 0, "0으로 나누어 크래시하면 안 된다.")
    }

    func testStableUUIDIsReproducibleAndValidV4() {
        let first = UUID(stableSeed: "quote:churchill-courage-to-continue")
        let second = UUID(stableSeed: "quote:churchill-courage-to-continue")
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, UUID(stableSeed: "quote:other"))

        let versionNibble = first.uuidString.split(separator: "-")[2].first
        XCTAssertEqual(versionNibble, "4")
    }

    // MARK: - 도우미

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
