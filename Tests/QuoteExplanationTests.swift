import XCTest
@testable import QuoteDay

/// 기기 모델은 CI 에서 돌릴 수 없다. 그래서 **모델을 둘러싼 로직**을 검사한다.
///
/// - 프롬프트에 명언·인물·언어가 제대로 들어가는지
/// - 캐시가 언어별로 갈리고, 오래된 것부터 지워지는지
/// - 화면이 기대는 상태 전이(대기 → 생성 중 → 완성)와 저장
/// - 기기에서 못 쓸 때 **안내 문구**가 비어 있지 않은지
final class QuoteExplanationTests: XCTestCase {

    private var directory: URL!
    private var cacheURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuoteExplanationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("explanations.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var sampleQuote: Quote {
        Quote(
            slug: "churchill-never-give-in",
            text: "절대로 포기하지 마라.",
            originalText: "Never give in.",
            authorID: "churchill",
            category: .work
        )
    }

    private var sampleAuthor: Author {
        Author(
            id: "churchill",
            name: "Winston Churchill",
            koreanName: "윈스턴 처칠",
            birthYear: 1874,
            deathYear: 1965,
            occupation: "정치인",
            nationality: "영국",
            biography: "",
            era: ""
        )
    }

    // MARK: - 프롬프트

    @MainActor
    func testPromptCarriesQuoteAuthorAndLanguage() {
        let prompt = QuoteExplainerPrompt.prompt(
            quote: sampleQuote, author: sampleAuthor, language: .english
        )
        XCTAssertTrue(prompt.contains("절대로 포기하지 마라."), "명언 본문이 빠졌다.")
        XCTAssertTrue(prompt.contains("Never give in."), "원문이 빠졌다.")
        XCTAssertTrue(prompt.contains("윈스턴 처칠"), "인물 이름이 빠졌다.")
        XCTAssertTrue(prompt.contains("정치인"), "직업이 빠졌다.")
        XCTAssertTrue(prompt.contains("English"), "언어 지시가 빠졌다.")
    }

    @MainActor
    func testInstructionsAskForEveryLanguage() {
        for language in AppLanguage.allCases {
            let instructions = QuoteExplainerPrompt.instructions(language: language)
            XCTAssertTrue(
                instructions.contains(QuoteExplainerPrompt.languageName(language)),
                "\(language.rawValue) 지시문에 언어 이름이 없다."
            )
            // 사실을 지어내지 말라는 규칙은 언어와 무관하게 늘 있어야 한다.
            XCTAssertTrue(instructions.contains("지어내지 않는다"))
        }
    }

    @MainActor
    func testPromptVersionIsInCacheKey() {
        let key = QuoteExplainerPrompt.cacheKey(slug: "a", language: .korean)
        XCTAssertTrue(key.contains("p\(QuoteExplainerPrompt.promptVersion)m\(QuoteExplainerPrompt.modelVersion)"))
        XCTAssertNotEqual(
            key,
            QuoteExplainerPrompt.cacheKey(slug: "a", language: .english),
            "언어가 다른데 같은 키를 쓰면 영어 해설이 한국어 화면에 나온다."
        )
    }

    // MARK: - 해설 모델

    @MainActor
    func testSectionsSkipEmptyParts() {
        let partial = QuoteExplanation(summary: "요지", context: "  ", practice: "")
        XCTAssertEqual(partial.sections.count, 1)
        XCTAssertEqual(partial.sections.first?.kind, .summary)
        XCTAssertFalse(partial.isComplete)
    }

    @MainActor
    func testEverySectionHasTitleAndSymbol() {
        for section in QuoteExplanation.Section.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.symbol.isEmpty)
        }
    }

    // MARK: - 쓸 수 없는 이유

    @MainActor
    func testEveryUnavailableReasonExplainsItself() {
        let reasons: [QuoteExplainerAvailability] = [
            .requiresNewerOS, .appleIntelligenceDisabled, .deviceNotEligible,
            .modelNotReady, .unsupportedLanguage(.korean)
        ]
        for reason in reasons {
            let text = reason.explanation
            XCTAssertNotNil(text, "\(reason) 에 안내 문구가 없다.")
            XCTAssertFalse(text!.isEmpty)
            XCTAssertFalse(reason.canExplain)
        }
        XCTAssertNil(QuoteExplainerAvailability.available.explanation)
        XCTAssertTrue(QuoteExplainerAvailability.available.canExplain)
    }

    @MainActor
    func testOnlyTheDisabledSwitchOffersSettings() {
        XCTAssertNotNil(QuoteExplainerAvailability.appleIntelligenceDisabled.settingsURL)
        XCTAssertNil(QuoteExplainerAvailability.requiresNewerOS.settingsURL)
    }

    // MARK: - 캐시

    @MainActor
    func testCacheRoundTrip() {
        let cache = QuoteExplanationCache(fileURL: cacheURL)
        let explanation = QuoteExplanation(summary: "요지", context: "배경", practice: "행동")
        XCTAssertTrue(cache.save(explanation, forKey: "k1"))
        XCTAssertEqual(cache.explanation(forKey: "k1"), explanation)
        XCTAssertEqual(cache.count(), 1)
    }

    @MainActor
    func testCacheKeepsOnlyTheNewestEntries() {
        let cache = QuoteExplanationCache(fileURL: cacheURL, limit: 3)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<5 {
            let explanation = QuoteExplanation(summary: "\(index)", context: "c", practice: "p")
            cache.save(explanation, forKey: "k\(index)", now: base.addingTimeInterval(Double(index)))
        }
        let loaded = cache.load()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertNil(loaded["k0"], "가장 오래된 것이 남아 있다.")
        XCTAssertNil(loaded["k1"])
        XCTAssertNotNil(loaded["k4"], "가장 최근 것이 지워졌다.")
    }

    @MainActor
    func testCacheRemoveAndClear() {
        let cache = QuoteExplanationCache(fileURL: cacheURL)
        cache.save(QuoteExplanation(summary: "a", context: "b", practice: "c"), forKey: "k1")
        cache.save(QuoteExplanation(summary: "d", context: "e", practice: "f"), forKey: "k2")
        cache.remove(forKey: "k1")
        XCTAssertEqual(cache.count(), 1)
        cache.clear()
        XCTAssertEqual(cache.count(), 0)
    }

    @MainActor
    func testBrokenCacheFileDoesNotCrash() throws {
        try Data("이건 JSON 이 아니다".utf8).write(to: cacheURL)
        let cache = QuoteExplanationCache(fileURL: cacheURL)
        XCTAssertEqual(cache.load().count, 0)
        // 깨진 파일 위에 다시 쓸 수 있어야 한다.
        XCTAssertTrue(cache.save(QuoteExplanation(summary: "a", context: "b", practice: "c"), forKey: "k"))
        XCTAssertEqual(cache.count(), 1)
    }

    // MARK: - 저장소 상태 전이

    @MainActor
    func testExplainGoesFromIdleToReadyAndSaves() async {
        let explainer = FakeExplainer(availability: .available)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )

        XCTAssertEqual(store.phase(for: sampleQuote, language: .korean), .idle)
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()

        guard case .ready(let explanation) = store.phase(for: sampleQuote, language: .korean) else {
            return XCTFail("완성 상태가 아니다: \(store.phase(for: sampleQuote, language: .korean))")
        }
        XCTAssertEqual(explanation.summary, "요지")
        // 파일에도 남아야 앱을 다시 열어도 다시 만들지 않는다.
        XCTAssertEqual(QuoteExplanationCache(fileURL: cacheURL).count(), 1)
    }

    @MainActor
    func testSecondRequestUsesStoredExplanation() async {
        let explainer = FakeExplainer(availability: .available)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()
        let firstCalls = explainer.callCount

        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        XCTAssertEqual(explainer.callCount, firstCalls, "저장된 해설이 있는데 다시 만들었다.")
    }

    @MainActor
    func testLanguageChangeAsksForANewExplanation() async {
        let explainer = FakeExplainer(availability: .available)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()

        XCTAssertEqual(store.phase(for: sampleQuote, language: .english), .idle)
    }

    @MainActor
    func testUnavailableShowsMessageAndNeverCallsModel() async {
        let explainer = FakeExplainer(availability: .deviceNotEligible)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)

        guard case .failed(let message) = store.phase(for: sampleQuote, language: .korean) else {
            return XCTFail("실패 상태가 아니다.")
        }
        XCTAssertEqual(message, QuoteExplainerAvailability.deviceNotEligible.explanation)
        XCTAssertEqual(explainer.callCount, 0, "기기에서 못 쓰는데 모델을 부르면 안 된다.")
    }

    @MainActor
    func testRegenerateReplacesTheStoredExplanation() async {
        let explainer = FakeExplainer(availability: .available)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()

        explainer.summary = "새 요지"
        store.regenerate(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()

        guard case .ready(let explanation) = store.phase(for: sampleQuote, language: .korean) else {
            return XCTFail("재생성 후 완성 상태가 아니다.")
        }
        XCTAssertEqual(explanation.summary, "새 요지")
        XCTAssertEqual(explainer.callCount, 2)
    }

    @MainActor
    func testSavedCountIsPerLanguage() async {
        let explainer = FakeExplainer(availability: .available)
        let store = QuoteExplanationStore(
            explainer: explainer,
            cache: QuoteExplanationCache(fileURL: cacheURL)
        )
        store.explain(quote: sampleQuote, author: sampleAuthor, language: .korean)
        await explainer.waitUntilFinished()

        XCTAssertEqual(store.savedCount(for: .korean), 1)
        XCTAssertEqual(store.savedCount(for: .english), 0)
        XCTAssertEqual(store.savedCount(), 1)
    }
}

/// 기기 모델 대신 쓰는 가짜. 실제 모델처럼 부분 결과를 한 번 보낸다.
@MainActor
final class FakeExplainer: QuoteExplaining {
    private let fixedAvailability: QuoteExplainerAvailability
    private(set) var callCount = 0
    var summary = "요지"

    init(availability: QuoteExplainerAvailability) {
        self.fixedAvailability = availability
    }

    func availability(for language: AppLanguage) -> QuoteExplainerAvailability {
        fixedAvailability
    }

    func explain(
        quote: Quote,
        author: Author,
        language: AppLanguage,
        onUpdate: @escaping @MainActor (QuoteExplanation) -> Void
    ) async throws -> QuoteExplanation {
        callCount += 1
        onUpdate(QuoteExplanation(summary: summary, context: "", practice: ""))
        // 저장소가 만든 Task 가 끝날 때까지 기다릴 수 있게 한 번 양보한다.
        await Task.yield()
        return QuoteExplanation(summary: summary, context: "배경", practice: "행동")
    }

    /// 저장소의 비동기 작업이 끝나기를 기다린다. (테스트 전용)
    func waitUntilFinished() async {
        for _ in 0..<50 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
