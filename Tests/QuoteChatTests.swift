import XCTest
@testable import QuoteDay

/// AI 대화의 **순수 로직**을 검사한다.
///
/// 실제 모델은 CI 에서 부를 수 없다(Foundation Models 는 기기, MLX 는 실기기).
/// 대신
/// - 화면의 상태 전이(질문 → 답하는 중 → 완성, 실패, 중단)
/// - 스냅숏/델타 두 방식의 조각을 합치는 규칙
/// - 프롬프트에 명언·작가·언어가 들어가는지
/// 를 지킨다. 이것들이 틀어지면 답이 아니라 오류가 온다.
final class QuoteChatTests: XCTestCase {

    // MARK: - 오류

    func testEveryErrorHasAMessage() {
        let errors: [QuoteChatError] = [
            .onDeviceUnavailable(.requiresNewerOS),
            .localModelMissing(.small),
            .localNotOnSimulator,
            .localModelFailed("no space"),
            .onDeviceFailed("boom"),
            .emptyReply
        ]
        for error in errors {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty, "\(error) 에 문구가 없다.")
        }
    }

    // MARK: - 프롬프트

    func testContextBlockCarriesQuoteAndAuthor() {
        let context = QuoteChatContext(quote: sampleQuote, author: sampleAuthor)
        let block = QuoteChatPrompt.contextBlock(context, language: .korean)
        XCTAssertTrue(block.contains("절대로 포기하지 마라."))
        XCTAssertTrue(block.contains("윈스턴 처칠"))
        XCTAssertTrue(block.contains("1874–1965"))
    }

    func testContextBlockIncludesCuratedStoryWhenPresent() {
        let story = BehindStory(
            quoteSlug: sampleQuote.slug,
            occasion: "전시 연설",
            context: "학교에서 한 짧은 연설이다.",
            takeaway: "끝까지 간다.",
            source: "연설 기록"
        )
        let block = QuoteChatPrompt.contextBlock(
            QuoteChatContext(quote: sampleQuote, author: sampleAuthor, story: story),
            language: .korean
        )
        XCTAssertTrue(block.contains("전시 연설"))
        XCTAssertTrue(block.contains("사람이 쓴 확인된 자료"))
    }

    func testInstructionsNameTheLanguage() {
        for language in AppLanguage.allCases {
            let text = QuoteChatPrompt.instructions(language: language)
            XCTAssertTrue(text.contains(QuoteChatPrompt.languageName(language)))
        }
    }

    /// 시스템 지침의 맨 앞 줄이 언어 규칙이어야 한다. 작은 모델은 긴 지침의 뒤쪽 규칙을 잊는다.
    func testInstructionsLeadWithTheLanguageRule() {
        for language in AppLanguage.allCases {
            let text = QuoteChatPrompt.instructions(language: language)
            XCTAssertTrue(
                text.hasPrefix("Reply language: \(QuoteChatPrompt.languageName(language))"),
                "\(language) 의 지침이 언어 규칙으로 시작하지 않는다."
            )
        }
    }

    /// 사용자가 "내가 무슨 언어인지 모른다" 고 했다. 질문마다 앱 언어를 끝에 한 번 더 적는다.
    func testEveryLocalQuestionCarriesTheAppLanguageAndNoThink() {
        var seen = Set<String>()
        for language in AppLanguage.allCases {
            let prompt = QuoteChatPrompt.localPrompt(question: "무슨 뜻이야?", language: language)
            XCTAssertTrue(prompt.hasPrefix("무슨 뜻이야?"), "사용자의 질문이 그대로 앞에 와야 한다.")
            XCTAssertTrue(prompt.hasSuffix(QuoteChatPrompt.noThinkSwitch), "생각 끄기가 맨 끝이어야 먹는다.")
            XCTAssertTrue(prompt.contains(QuoteChatPrompt.languageReminder(language)))
            seen.insert(QuoteChatPrompt.languageReminder(language))
        }
        XCTAssertEqual(seen.count, AppLanguage.allCases.count, "언어마다 지시가 달라야 한다.")
    }

    func testPromptVersionWasBumpedForTheNewInstructions() {
        XCTAssertGreaterThanOrEqual(QuoteChatPrompt.version, 3)
    }

    /// 실기기에서 "이 명언의 숨은 뜻이 뭐야?" 에 "어떤 명언인지 알려 주세요" 라고 되물었다.
    /// 명언이 시스템 지침에만 있어서 작은 모델이 질문과 연결하지 못했다. 질문 옆에 붙어야 한다.
    func testLocalQuestionCarriesTheQuoteNextToIt() {
        let context = QuoteChatContext(quote: sampleQuote, author: sampleAuthor)
        let prompt = QuoteChatPrompt.localPrompt(question: "이 명언의 숨은 뜻이 뭐야?", language: .korean, context: context)

        XCTAssertTrue(prompt.contains("절대로 포기하지 마라."), "명언 본문이 질문과 함께 가야 한다.")
        XCTAssertTrue(prompt.contains("윈스턴 처칠"))
        XCTAssertTrue(prompt.contains("질문: 이 명언의 숨은 뜻이 뭐야?"))
        XCTAssertTrue(prompt.hasSuffix(QuoteChatPrompt.noThinkSwitch))

        let quoteAt = try? XCTUnwrap(prompt.range(of: "절대로 포기하지 마라.")?.lowerBound)
        let questionAt = try? XCTUnwrap(prompt.range(of: "질문:")?.lowerBound)
        if let quoteAt, let questionAt {
            XCTAssertLessThan(quoteAt, questionAt, "명언이 질문보다 앞에 와야 \"이 명언\" 이 무엇인지 읽힌다.")
        }
    }

    func testCompactQuoteLineIsShort() {
        let line = QuoteChatPrompt.compactQuoteLine(QuoteChatContext(quote: sampleQuote, author: sampleAuthor))
        XCTAssertTrue(line.contains("윈스턴 처칠"))
        XCTAssertLessThan(line.count, 200, "질문 옆에 붙이는 한 줄이 길어지면 작은 모델의 문맥을 갉아먹는다.")
    }

    func testContextForAChosenQuoteCarriesItsAuthor() throws {
        let quote = try XCTUnwrap(QuoteService.shared.allQuotes.first)
        let context = QuoteChatContext.make(for: quote)
        XCTAssertEqual(context.quote.slug, quote.slug)
        XCTAssertFalse(context.author.displayName.isEmpty)
    }

    func testSuggestionsFollowContext() {
        XCTAssertTrue(QuoteChatPrompt.suggestions(hasContext: true).count >= 3)
        XCTAssertTrue(QuoteChatPrompt.suggestions(hasContext: false).count >= 3)
        XCTAssertNotEqual(
            QuoteChatPrompt.suggestions(hasContext: true),
            QuoteChatPrompt.suggestions(hasContext: false)
        )
    }

    // MARK: - 엔진 상태 전이

    @MainActor
    func testSendStreamsThenFinishes() async throws {
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["요지는 ", "짧다."]) })
        let settings = try makeDownloadedSettings()

        engine.send("무슨 뜻이야?", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.messages.count, 2)
        XCTAssertEqual(engine.messages[0].role, .user)
        XCTAssertEqual(engine.messages[0].text, "무슨 뜻이야?")
        XCTAssertEqual(engine.messages[1].role, .assistant)
        XCTAssertEqual(engine.messages[1].text, "요지는 짧다.")
        XCTAssertFalse(engine.messages[1].isStreaming)
        XCTAssertNil(engine.errorMessage)
    }

    @MainActor
    func testFailureShowsMessageAndDropsEmptyBubble() async throws {
        let engine = QuoteChatEngine(makeTransport: { _ in FailingTransport() })
        let settings = try makeDownloadedSettings()

        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(
            engine.errorMessage,
            QuoteChatError.localModelFailed("저장 공간이 부족합니다").errorDescription
        )
        XCTAssertEqual(engine.messages.count, 1, "빈 답변 말풍선은 남기지 않는다.")
        XCTAssertEqual(engine.messages[0].role, .user)
    }

    @MainActor
    func testMissingModelNeverCallsTheTransport() async {
        let transport = FakeTransport(chunks: ["x"])
        let engine = QuoteChatEngine(makeTransport: { _ in transport })
        let settings = makeSettingsWithoutModel()

        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(
            engine.errorMessage,
            QuoteChatError.localModelMissing(settings.localModel).errorDescription
        )
        XCTAssertEqual(transport.callCount, 0)
    }

    @MainActor
    func testClearRemovesEverything() async throws {
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["답"]) })
        let settings = try makeDownloadedSettings()
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        engine.clear()
        XCTAssertTrue(engine.messages.isEmpty)
        XCTAssertNil(engine.errorMessage)
        XCTAssertFalse(engine.isSending)
    }

    @MainActor
    func testEmptyQuestionIsIgnored() async throws {
        let transport = FakeTransport(chunks: ["답"])
        let engine = QuoteChatEngine(makeTransport: { _ in transport })
        let settings = try makeDownloadedSettings()

        engine.send("   ", context: nil, settings: settings, language: .korean)
        XCTAssertTrue(engine.messages.isEmpty)
        XCTAssertEqual(transport.callCount, 0)
    }

    @MainActor
    func testSnapshotStyleDeltasDoNotDuplicateText() async throws {
        // 온디바이스 모델은 조각마다 "전체 글"을 준다. 이어 붙이면 글이 중복된다.
        let engine = QuoteChatEngine(makeTransport: { _ in
            FakeTransport(chunks: ["요지", "요지는", "요지는 짧다"], yieldsSnapshots: true)
        })
        let settings = try makeDownloadedSettings()
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.messages.last?.text, "요지는 짧다")
    }

    /// 델타를 주는 통로(Qwen)에서 글머리와 같은 조각이 사라지던 결함.
    /// 예전 규칙은 "조각이 지금까지의 글 앞부분과 같으면 버린다" 여서 `이` 가 통째로 빠졌다.
    @MainActor
    func testDeltaThatRepeatsTheStartOfTheAnswerIsKept() async throws {
        let engine = QuoteChatEngine(makeTransport: { _ in
            FakeTransport(chunks: ["이", "것은 ", "이", "유가 있다"])
        })
        let settings = try makeDownloadedSettings()
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.messages.last?.text, "이것은 이유가 있다")
    }

    // MARK: - 설정

    @MainActor
    func testLocalModelNeedsDownloadFirst() {
        let service = makeLocalService()
        let settings = AIChatSettings(defaults: makeDefaults(), localService: service)
        settings.provider = .localQwen

        guard case .needsDownload = settings.availability else {
            return XCTFail("받기 전에는 내려받기 안내가 나와야 한다: \(settings.availability)")
        }
    }

    @MainActor
    func testProviderDefaultIsOnDevice() {
        let settings = AIChatSettings(defaults: makeDefaults(), localService: makeLocalService())
        XCTAssertEqual(settings.provider, .onDevice)
        XCTAssertEqual(settings.localChoice, .automatic)
        // 어떤 통로도 기기 밖으로 나가지 않는다.
        XCTAssertFalse(settings.provider.leavesDevice)
    }

    @MainActor
    func testChoiceIsPersisted() {
        let defaults = makeDefaults()
        let first = AIChatSettings(defaults: defaults, localService: makeLocalService())
        first.provider = .localQwen
        first.localChoice = .large

        let second = AIChatSettings(defaults: defaults, localService: makeLocalService())
        XCTAssertEqual(second.provider, .localQwen)
        XCTAssertEqual(second.localChoice, .large)
    }

    // MARK: - 도우미

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

    /// Qwen3 를 이미 받아 둔 기기를 흉내 낸 설정. 엔진 상태 전이를 볼 때 쓴다.
    @MainActor
    private func makeDownloadedSettings() throws -> AIChatSettings {
        let service = makeLocalService()
        let settings = AIChatSettings(defaults: makeDefaults(), localService: service)
        settings.provider = .localQwen
        settings.localChoice = .small

        let directory = service.directory(for: .small)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("config.json"))
        try Data(repeating: 0, count: 8).write(to: directory.appendingPathComponent("w.safetensors"))
        service.refresh()
        return settings
    }

    /// 아직 아무것도 받지 않은 기기.
    @MainActor
    private func makeSettingsWithoutModel() -> AIChatSettings {
        let settings = AIChatSettings(defaults: makeDefaults(), localService: makeLocalService())
        settings.provider = .localQwen
        return settings
    }

    @MainActor
    private func makeLocalService() -> LocalQwenService {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuoteChatTests-\(UUID().uuidString)", isDirectory: true)
        return LocalQwenService(downloadBase: base, canRun: true)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "QuoteChatTests-\(UUID().uuidString)") ?? .standard
    }

    @MainActor
    private func waitFor(
        _ engine: QuoteChatEngine,
        until condition: () -> Bool,
        timeout: Int = 60
    ) async {
        for _ in 0..<timeout {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("조건이 시간 안에 만족되지 않았다.")
    }
}

// MARK: - 가짜 통로

@MainActor
final class FakeTransport: QuoteChatTransport {
    let chunks: [String]
    let yieldsSnapshots: Bool
    private(set) var callCount = 0

    init(chunks: [String], yieldsSnapshots: Bool = false) {
        self.chunks = chunks
        self.yieldsSnapshots = yieldsSnapshots
    }

    func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage,
        context: QuoteChatContext?
    ) -> AsyncThrowingStream<String, Error> {
        callCount += 1
        let chunks = self.chunks
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                    await Task.yield()
                }
                continuation.finish()
            }
        }
    }
}

@MainActor
final class FailingTransport: QuoteChatTransport {
    func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage,
        context: QuoteChatContext?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: QuoteChatError.localModelFailed("저장 공간이 부족합니다"))
        }
    }
}
