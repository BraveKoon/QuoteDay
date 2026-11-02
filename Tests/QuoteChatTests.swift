import XCTest
@testable import QuoteDay

/// AI 대화의 **순수 로직**을 검사한다.
///
/// 실제 모델(Qwen·온디바이스)은 CI 에서 부를 수 없다. 대신
/// - SSE 한 줄을 제대로 해석하는지(델타·끝·오류·모르는 줄)
/// - 요청 본문이 OpenAI 호환 규격인지
/// - 화면의 상태 전이(질문 → 답하는 중 → 완성, 실패, 중단)
/// - 프롬프트에 명언·작가·언어가 들어가는지
/// 를 지킨다. 이것들이 틀어지면 답이 아니라 오류가 온다.
final class QuoteChatTests: XCTestCase {

    // MARK: - SSE 해석

    func testDeltaLineIsParsed() {
        let line = #"data: {"choices":[{"delta":{"content":"안녕"}}]}"#
        XCTAssertEqual(QwenSSE.parse(line: line), .delta("안녕"))
    }

    func testDoneLineEndsTheStream() {
        XCTAssertEqual(QwenSSE.parse(line: "data: [DONE]"), .done)
    }

    func testEmptyDeltaIsIgnored() {
        // 첫 조각은 role 만 오고 content 가 빈 경우가 흔하다.
        let line = #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#
        XCTAssertEqual(QwenSSE.parse(line: line), .ignore)
    }

    func testErrorPayloadInsideStreamIsSurfaced() {
        let line = #"data: {"error":{"message":"model not found","code":"InvalidParameter"}}"#
        XCTAssertEqual(QwenSSE.parse(line: line), .error("model not found"))
    }

    func testNonDataLinesAreIgnored() {
        XCTAssertEqual(QwenSSE.parse(line: ""), .ignore)
        XCTAssertEqual(QwenSSE.parse(line: ": keep-alive"), .ignore)
        XCTAssertEqual(QwenSSE.parse(line: "event: message"), .ignore)
        XCTAssertEqual(QwenSSE.parse(line: "data: not json"), .ignore)
    }

    func testMessageContentFallbackIsAccepted() {
        // 일부 구현은 delta 대신 message.content 로 준다.
        let line = #"data: {"choices":[{"message":{"content":"답"}}]}"#
        XCTAssertEqual(QwenSSE.parse(line: line), .delta("답"))
    }

    // MARK: - 요청 본문

    func testRequestBodyIsOpenAICompatible() throws {
        let messages = [
            QuoteChatMessage(role: .user, text: "이 명언 무슨 뜻이야?"),
            QuoteChatMessage(role: .assistant, text: "요지는 …"),
            QuoteChatMessage(role: .user, text: "작가 이야기도 해 줘")
        ]
        let data = try QwenChatTransport.body(
            system: "지시문", messages: messages, model: "qwen-plus"
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["model"] as? String, "qwen-plus")
        XCTAssertEqual(object["stream"] as? Bool, true)

        let sent = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(sent.first?["role"], "system")
        XCTAssertEqual(sent.first?["content"], "지시문")
        XCTAssertEqual(sent.dropFirst().map { $0["role"] }, ["user", "assistant", "user"])
        XCTAssertEqual(sent.last?["content"], "작가 이야기도 해 줘")
    }

    func testLongHistoryIsTrimmed() throws {
        // 문맥 한도를 넘기면 요청이 거부된다. 오래된 대화는 잘라 낸다.
        let messages = (0..<40).map { index in
            QuoteChatMessage(role: index % 2 == 0 ? .user : .assistant, text: "\(index)")
        }
        let data = try QwenChatTransport.body(system: "s", messages: messages, model: "m", maxTurns: 6)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sent = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(sent.count, 1 + 6, "system + 최근 6개만 남아야 한다.")
        XCTAssertEqual(sent.last?["content"], "39")
    }

    func testEmptyMessagesAreNotSent() throws {
        let messages = [
            QuoteChatMessage(role: .user, text: "질문"),
            QuoteChatMessage(role: .assistant, text: "   ")
        ]
        let data = try QwenChatTransport.body(system: "s", messages: messages, model: "m")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sent = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(sent.count, 2, "빈 답변은 보내지 않는다.")
    }

    func testStatusCodesMapToReadableReasons() {
        XCTAssertEqual(QwenChatTransport.error(status: 401, body: ""), .unauthorized)
        XCTAssertEqual(QwenChatTransport.error(status: 403, body: ""), .unauthorized)
        XCTAssertEqual(QwenChatTransport.error(status: 429, body: ""), .rateLimited)
        XCTAssertEqual(QwenChatTransport.error(status: 500, body: ""), .server(500))
        guard case .badRequest = QwenChatTransport.error(status: 400, body: "bad model") else {
            return XCTFail("400 은 badRequest 여야 한다.")
        }
    }

    func testEveryErrorHasAMessage() {
        let errors: [QuoteChatError] = [
            .missingKey, .unauthorized, .rateLimited, .server(500), .offline,
            .badRequest("x"), .onDeviceUnavailable(.requiresNewerOS)
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
    func testSendStreamsThenFinishes() async {
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["요지는 ", "짧다."]) })
        let settings = makeSettings(provider: .qwen, key: "sk-test")

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
    func testFailureShowsMessageAndDropsEmptyBubble() async {
        let engine = QuoteChatEngine(makeTransport: { _ in FailingTransport() })
        let settings = makeSettings(provider: .qwen, key: "sk-test")

        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.errorMessage, QuoteChatError.unauthorized.errorDescription)
        XCTAssertEqual(engine.messages.count, 1, "빈 답변 말풍선은 남기지 않는다.")
        XCTAssertEqual(engine.messages[0].role, .user)
    }

    @MainActor
    func testMissingKeyNeverCallsTheNetwork() async {
        let transport = FakeTransport(chunks: ["x"])
        let engine = QuoteChatEngine(makeTransport: { _ in transport })
        let settings = makeSettings(provider: .qwen, key: nil)

        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.errorMessage, QuoteChatError.missingKey.errorDescription)
        XCTAssertEqual(transport.callCount, 0)
    }

    @MainActor
    func testClearRemovesEverything() async {
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["답"]) })
        let settings = makeSettings(provider: .qwen, key: "sk-test")
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        engine.clear()
        XCTAssertTrue(engine.messages.isEmpty)
        XCTAssertNil(engine.errorMessage)
        XCTAssertFalse(engine.isSending)
    }

    @MainActor
    func testEmptyQuestionIsIgnored() async {
        let transport = FakeTransport(chunks: ["답"])
        let engine = QuoteChatEngine(makeTransport: { _ in transport })
        let settings = makeSettings(provider: .qwen, key: "sk-test")

        engine.send("   ", context: nil, settings: settings, language: .korean)
        XCTAssertTrue(engine.messages.isEmpty)
        XCTAssertEqual(transport.callCount, 0)
    }

    @MainActor
    func testSnapshotStyleDeltasDoNotDuplicateText() async {
        // 온디바이스 모델은 조각마다 "전체 글"을 준다. 이어 붙이면 글이 중복된다.
        let engine = QuoteChatEngine(makeTransport: { _ in FakeTransport(chunks: ["요지", "요지는", "요지는 짧다"]) })
        let settings = makeSettings(provider: .qwen, key: "sk-test")
        engine.send("질문", context: nil, settings: settings, language: .korean)
        await waitFor(engine, until: { !engine.isSending })

        XCTAssertEqual(engine.messages.last?.text, "요지는 짧다")
    }

    // MARK: - 설정

    @MainActor
    func testProviderDefaultsToOnDevice() {
        let settings = AIChatSettings(defaults: makeDefaults(), keyStore: MemoryKeyStore())
        XCTAssertEqual(settings.provider, .onDevice)
        XCTAssertFalse(settings.provider.requiresKey)
        XCTAssertFalse(settings.provider.leavesDevice)
    }

    @MainActor
    func testQwenNeedsAKey() {
        let settings = AIChatSettings(defaults: makeDefaults(), keyStore: MemoryKeyStore())
        settings.provider = .qwen
        // 테스트 기기의 Keychain 상태에 기대지 않도록 키를 지우고 확인한다.
        settings.deleteKey()
        XCTAssertEqual(settings.availability, .needsKey)
        XCTAssertFalse(settings.availability.canChat)
    }

    @MainActor
    func testKeyRoundTripAndTrimming() {
        let store = MemoryKeyStore()
        let settings = AIChatSettings(defaults: makeDefaults(), keyStore: store)
        settings.provider = .qwen
        XCTAssertFalse(settings.hasKey)

        // 붙여 넣을 때 딸려 오는 공백·줄바꿈은 지운다.
        XCTAssertTrue(settings.saveKey("  sk-abc123\n"))
        XCTAssertTrue(settings.hasKey)
        XCTAssertEqual(store.stored, "sk-abc123")

        settings.deleteKey()
        XCTAssertFalse(settings.hasKey)
        XCTAssertEqual(settings.availability, .needsKey)
    }

    @MainActor
    func testEmptyKeyIsNotSaved() {
        let store = MemoryKeyStore()
        let settings = AIChatSettings(defaults: makeDefaults(), keyStore: store)
        XCTAssertFalse(settings.saveKey("   "))
        XCTAssertNil(store.stored)
    }

    func testQwenRegionURLs() {
        XCTAssertEqual(
            QwenRegion.international.chatURL?.absoluteString,
            "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"
        )
        XCTAssertEqual(
            QwenRegion.china.chatURL?.absoluteString,
            "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        )
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
    private func makeSettings(provider: AIChatProvider, key: String?) -> AIChatSettings {
        let settings = AIChatSettings(defaults: makeDefaults(), keyStore: MemoryKeyStore())
        settings.provider = provider
        if let key {
            settings.saveKey(key)
        } else {
            settings.deleteKey()
        }
        return settings
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

/// 테스트용 키 저장소. 진짜 Keychain 을 만지지 않는다.
final class MemoryKeyStore: APIKeyStore {
    private(set) var stored: String?

    func key() -> String? { stored }

    @discardableResult
    func save(_ key: String) -> Bool {
        stored = key
        return true
    }

    func delete() {
        stored = nil
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
            continuation.finish(throwing: QuoteChatError.unauthorized)
        }
    }
}
