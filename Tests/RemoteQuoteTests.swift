import XCTest
@testable import QuoteDay

/// ZenQuotes 응답 파싱, 캐시 판정, 내장 인물 매칭 검증.
///
/// 네트워크는 타지 않는다. 실제 호출은 실패해도 앱이 내장 명언으로
/// 되돌아가도록 설계되어 있으므로, 여기서는 순수 로직만 확인한다.
final class RemoteQuoteTests: XCTestCase {

    private let dayKey = "2026-08-15"

    private func makeStore(name: String = #function) -> (RemoteQuoteStore, UserDefaults) {
        let suite = "test.remoteQuote.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return (RemoteQuoteStore(defaults: defaults), defaults)
    }

    // MARK: - 파싱

    func testParsesStandardResponse() throws {
        let json = Data("""
        [{"q":"Success is not final.","a":"Winston Churchill","h":"<blockquote>...</blockquote>"}]
        """.utf8)

        let quote = try RemoteQuoteStore.parse(json, dayKey: dayKey)
        XCTAssertEqual(quote.text, "Success is not final.")
        XCTAssertEqual(quote.authorName, "Winston Churchill")
        XCTAssertEqual(quote.dayKey, dayKey)
    }

    func testTrimsWhitespace() throws {
        let json = Data("""
        [{"q":"  Keep going.  ","a":"  Anonymous Writer  ","h":""}]
        """.utf8)

        let quote = try RemoteQuoteStore.parse(json, dayKey: dayKey)
        XCTAssertEqual(quote.text, "Keep going.")
        XCTAssertEqual(quote.authorName, "Anonymous Writer")
    }

    /// 사용량 초과 시 ZenQuotes 는 200 과 함께 안내 문구를 본문에 담아 보낸다.
    /// 이걸 명언으로 저장하면 위젯에 "Too many requests" 가 뜬다.
    func testRejectsRateLimitPayload() {
        let json = Data("""
        [{"q":"Too many requests. Obtain an auth key for unlimited access.","a":"zenquotes.io","h":""}]
        """.utf8)

        XCTAssertThrowsError(try RemoteQuoteStore.parse(json, dayKey: dayKey)) { error in
            XCTAssertEqual(error as? RemoteQuoteError, .rateLimited)
        }
    }

    func testRejectsEmptyArray() {
        XCTAssertThrowsError(try RemoteQuoteStore.parse(Data("[]".utf8), dayKey: dayKey)) { error in
            XCTAssertEqual(error as? RemoteQuoteError, .emptyResponse)
        }
    }

    func testRejectsBlankFields() {
        let json = Data("""
        [{"q":"   ","a":"Someone","h":""}]
        """.utf8)
        XCTAssertThrowsError(try RemoteQuoteStore.parse(json, dayKey: dayKey))
    }

    func testRejectsMalformedJSON() {
        XCTAssertThrowsError(try RemoteQuoteStore.parse(Data("not json".utf8), dayKey: dayKey))
    }

    // MARK: - 식별자

    func testSlugAndIDAreStableForSameContent() {
        let first = RemoteQuote(text: "Keep going.", authorName: "Someone", dayKey: "2026-01-01")
        let second = RemoteQuote(text: "Keep going.", authorName: "Someone", dayKey: "2026-12-31")

        // 날짜가 달라도 내용이 같으면 같은 딥링크를 가리켜야 한다.
        XCTAssertEqual(first.slug, second.slug)
        XCTAssertEqual(first.quote().id, second.quote().id)
    }

    func testDifferentContentProducesDifferentID() {
        let first = RemoteQuote(text: "A", authorName: "Someone", dayKey: dayKey)
        let second = RemoteQuote(text: "B", authorName: "Someone", dayKey: dayKey)
        XCTAssertNotEqual(first.quote().id, second.quote().id)
    }

    func testRemoteQuoteIsMarkedAsRemote() {
        let remote = RemoteQuote(text: "A", authorName: "Someone", dayKey: dayKey)
        XCTAssertTrue(remote.quote().isFromZenQuotes)
        XCTAssertFalse(QuoteService.shared.quoteOfTheDay().isFromZenQuotes)
    }

    // MARK: - 인물 매칭

    func testMatchesBundledAuthorAndKeepsBiography() {
        let remote = RemoteQuote(text: "Success is not final.", authorName: "Winston Churchill", dayKey: dayKey)
        let author = remote.resolvedAuthor

        XCTAssertEqual(author.id, "churchill")
        XCTAssertEqual(author.birthYear, 1874)
        XCTAssertFalse(author.biography.isEmpty)
    }

    func testAuthorMatchingIgnoresCaseAndPunctuation() {
        XCTAssertEqual(AuthorLibrary.author(matchingName: "winston churchill")?.id, "churchill")
        XCTAssertEqual(AuthorLibrary.author(matchingName: "Martin Luther King, Jr.")?.id, "king")
        XCTAssertEqual(AuthorLibrary.author(matchingName: "마리 퀴리")?.id, "curie")
    }

    func testUnknownAuthorStillKeepsTheName() {
        let remote = RemoteQuote(text: "A", authorName: "Jane Q. Public", dayKey: dayKey)
        let author = remote.resolvedAuthor

        XCTAssertEqual(author.name, "Jane Q. Public")
        XCTAssertNotEqual(author.id, Author.unknown.id)
        XCTAssertFalse(author.biography.isEmpty, "소개가 비어 있으면 상세 화면이 허전해진다.")
    }

    func testUnmatchedNameReturnsNil() {
        XCTAssertNil(AuthorLibrary.author(matchingName: "존재하지 않는 사람"))
    }

    // MARK: - 캐시

    func testPresentationOnlyReturnedForMatchingDay() {
        let (store, _) = makeStore()
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let tomorrow = today.addingTimeInterval(24 * 60 * 60)

        store.save(RemoteQuote(text: "A", authorName: "Someone", dayKey: today.dayKey()))

        XCTAssertNotNil(store.presentation(on: today))
        XCTAssertNil(store.presentation(on: tomorrow), "어제 명언을 오늘 보여 주면 안 된다.")
    }

    func testPresentationMatchingIDIgnoresDay() {
        let (store, _) = makeStore()
        let remote = RemoteQuote(text: "A", authorName: "Someone", dayKey: "2020-01-01")
        store.save(remote)

        // 알림·위젯 딥링크는 날짜가 지나도 열려야 한다.
        XCTAssertNotNil(store.presentation(matching: remote.quote().id))
        XCTAssertNil(store.presentation(matching: UUID()))
    }

    func testEmptyCacheIsSafe() {
        let (store, _) = makeStore()
        XCTAssertNil(store.cached())
        XCTAssertNil(store.presentation())
        XCTAssertNil(store.presentation(matching: UUID()))
    }

    func testClearRemovesEverything() {
        let (store, _) = makeStore()
        store.save(RemoteQuote(text: "A", authorName: "Someone", dayKey: dayKey))
        store.clear()
        XCTAssertNil(store.cached())
    }

    func testEnabledDefaultsToTrue() {
        let (store, _) = makeStore()
        XCTAssertTrue(store.isEnabled, "값이 없으면 켜진 상태로 시작한다.")
    }

    func testDisabledStoreSkipsRefresh() async {
        let (store, defaults) = makeStore()
        defaults.set(false, forKey: SharedDefaultsKey.remoteQuoteEnabled)
        let didRefresh = await store.refreshIfNeeded()
        XCTAssertFalse(didRefresh, "꺼져 있으면 네트워크를 타지 않아야 한다.")
    }

    // MARK: - 폴백

    func testTodayPresentationFallsBackToBundledQuote() {
        let (store, _) = makeStore()
        let service = QuoteService.shared
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        // 캐시가 비어 있어도 화면은 채워져야 한다.
        let presentation = service.todayPresentation(for: date, useRemote: true, remote: store)
        XCTAssertEqual(presentation.quote.slug, service.quoteOfTheDay(for: date).slug)
        XCTAssertFalse(presentation.quote.isFromZenQuotes)
    }

    func testTodayPresentationUsesRemoteWhenAvailable() {
        let (store, _) = makeStore()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        store.save(RemoteQuote(text: "From the API.", authorName: "Someone", dayKey: date.dayKey()))

        let presentation = QuoteService.shared.todayPresentation(for: date, useRemote: true, remote: store)
        XCTAssertEqual(presentation.quote.text, "From the API.")
    }

    func testRemoteIgnoredWhenDisabled() {
        let (store, _) = makeStore()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        store.save(RemoteQuote(text: "From the API.", authorName: "Someone", dayKey: date.dayKey()))

        let presentation = QuoteService.shared.todayPresentation(for: date, useRemote: false, remote: store)
        XCTAssertFalse(presentation.quote.isFromZenQuotes)
    }

    func testDeepLinkResolvesRemoteQuote() {
        let (store, _) = makeStore()
        let remote = RemoteQuote(text: "Linkable.", authorName: "Someone", dayKey: dayKey)
        store.save(remote)

        let resolved = QuoteService.shared.presentation(id: remote.quote().id, remote: store)
        XCTAssertEqual(resolved?.quote.text, "Linkable.")
    }
}
