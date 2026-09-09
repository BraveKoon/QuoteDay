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

    // MARK: - 번역

    /// 번역이 없으면 영어 원문이 그대로 화면에 간다.
    func testDisplayTextFallsBackToEnglish() {
        let quote = RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: dayKey)
        XCTAssertEqual(quote.displayText, "Keep going.")
        XCTAssertTrue(quote.needsTranslation)
        XCTAssertNil(quote.quote().originalText, "번역 전에는 같은 문장이 두 번 나오면 안 된다.")
    }

    func testTranslationBecomesTheBodyAndEnglishMovesToOriginal() {
        let quote = RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: dayKey)
            .withTranslation("계속 나아가라.")

        XCTAssertEqual(quote.displayText, "계속 나아가라.")
        XCTAssertFalse(quote.needsTranslation)
        XCTAssertEqual(quote.quote().text, "계속 나아가라.")
        XCTAssertEqual(quote.quote().originalText, "Keep going.")
    }

    /// **번역해도 slug 와 UUID 가 바뀌면 안 된다.**
    /// 알림과 위젯 딥링크가 그 값을 들고 있어서, 바뀌면 링크가 통째로 끊긴다.
    func testTranslationNeverChangesTheIdentity() {
        let original = RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: dayKey)
        let translated = original.withTranslation("계속 나아가라.")

        XCTAssertEqual(translated.slug, original.slug)
        XCTAssertEqual(translated.quote().id, original.quote().id)
    }

    func testSavedTranslationIsReadBack() {
        let (store, _) = makeStore()
        let quote = RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: dayKey)
        store.save(quote)

        store.saveTranslation("계속 나아가라.", forSourceText: "Keep going.")

        XCTAssertEqual(store.cached()?.translatedText, "계속 나아가라.")
        XCTAssertEqual(store.cached()?.text, "Keep going.", "원문은 그대로 남아야 한다.")
    }

    /// 번역이 끝나기 전에 날짜가 바뀌어 다른 명언을 받아 왔을 수 있다.
    /// 그때 엉뚱한 문장에 번역이 붙으면 안 된다.
    func testTranslationForAnotherQuoteIsIgnored() {
        let (store, _) = makeStore()
        store.save(RemoteQuote(text: "Today's quote.", authorName: "Anon", dayKey: dayKey))

        store.saveTranslation("어제 명언의 번역", forSourceText: "Yesterday's quote.")

        XCTAssertNil(store.cached()?.translatedText)
    }

    func testEmptyOrUnchangedTranslationIsIgnored() {
        let (store, _) = makeStore()
        store.save(RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: dayKey))

        store.saveTranslation("   ", forSourceText: "Keep going.")
        XCTAssertNil(store.cached()?.translatedText)

        // 번역기가 원문을 그대로 돌려주면 번역하지 않은 것과 같다.
        store.saveTranslation("Keep going.", forSourceText: "Keep going.")
        XCTAssertNil(store.cached()?.translatedText)
    }

    func testPendingSourceOnlyForTodaysUntranslatedQuote() {
        let (store, _) = makeStore()
        let today = Date()
        let todayKey = today.dayKey(calendar: .current)

        XCTAssertNil(store.pendingTranslationSource(on: today), "캐시가 비어 있으면 할 일이 없다.")

        store.save(RemoteQuote(text: "Keep going.", authorName: "Anon", dayKey: todayKey))
        XCTAssertEqual(store.pendingTranslationSource(on: today), "Keep going.")

        store.saveTranslation("계속 나아가라.", forSourceText: "Keep going.")
        XCTAssertNil(store.pendingTranslationSource(on: today), "이미 번역했으면 다시 하지 않는다.")

        // 어제 것은 어차피 화면에 안 나오므로 번역하지 않는다.
        store.save(RemoteQuote(text: "Old one.", authorName: "Anon", dayKey: "1999-01-01"))
        XCTAssertNil(store.pendingTranslationSource(on: today))
    }

    /// 번역 필드가 없던 예전 캐시도 그대로 읽혀야 한다. 마이그레이션은 두지 않았다.
    func testCacheFromBeforeTranslationStillDecodes() throws {
        let (store, defaults) = makeStore()
        let legacy = Data("""
        {"text":"Keep going.","authorName":"Anon","dayKey":"\(dayKey)","fetchedAt":"2026-08-15T00:00:00Z"}
        """.utf8)
        defaults.set(legacy, forKey: SharedDefaultsKey.remoteQuote)

        let cached = try XCTUnwrap(store.cached())
        XCTAssertEqual(cached.text, "Keep going.")
        XCTAssertNil(cached.translatedText)
        XCTAssertTrue(cached.needsTranslation)
    }

}
