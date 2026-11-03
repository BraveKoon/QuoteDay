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
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["요지", "요지는", "요지는 짧다"]) })
        let settings = try makeDownloadedSettings()
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.messages.last?.text, "요지는 짧다")
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

    @MainActor
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
    private(set) var callCount = 0

    init(chunks: [String]) {
        self.chunks = chunks
    }

    func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage
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
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: QuoteChatError.localModelFailed("저장 공간이 부족합니다"))
        }
    }
}
