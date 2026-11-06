import Foundation

/// **기기 안에서 도는 Qwen3** 로 대화하는 통로.
///
/// 클라우드 통로(`QwenChatTransport`)와 하는 일은 같다: 지금까지의 대화를 받아
/// 다음 말을 조각조각 돌려준다. 다른 점은 **아무것도 기기 밖으로 나가지 않는다**는
/// 것과, 답이 느리다는 것뿐이다.
///
/// 실제 일은 `LocalQwenService` 가 한다. 이 타입은 엔진이 아는 약속
/// (`QuoteChatTransport`)에 서비스를 끼워 넣는 얇은 어댑터다. 엔진과 화면은
/// MLX 를 몰라도 되고, 테스트는 MLX 없이 돌릴 수 있다.
@MainActor
public final class LocalQwenChatTransport: QuoteChatTransport {
    private let service: LocalQwenService
    /// 어떤 크기를 쓸지. 설정이 바뀌면 엔진이 새 통로를 만든다.
    private let model: LocalQwenModel

    public init(service: LocalQwenService = .shared, model: LocalQwenModel) {
        self.service = service
        self.model = model
    }

    public func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage,
        context: QuoteChatContext?
    ) -> AsyncThrowingStream<String, Error> {
        // **매 질문을 새 세션으로 시작한다.** 처음에는 세션이 대화를 기억하게 두었는데,
        // 1.15.4 실기기에서 모델이 `야` 에 `야` 라고 한 번 답하자 그 뒤의 모든 질문
        // (`안녕`, `숨은 뜻 알려줘`)에 `야` 만 내놓았다. 작은 모델은 자기 앞 답을 그대로
        // 베낀다 — 한 번 무너진 답이 기록에 남으면 대화 전체가 무너진다.
        // 앞서 사용자가 물은 **질문만** 질문 옆에 적어 준다(`recap` 의 설명 — 앞 답은 넣지 않는다).
        // 지침을 매번 다시 읽히는 값(1.7B 에서 1~2초)이 대화가 통째로 망가지는 것보다 싸다.
        let question = messages.last(where: { $0.role == .user })?.text.trimmed ?? ""
        guard !question.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }
        // 인사·"넌 누구야"·웃음, 작가의 국적·생몰·직업·일생은 앱이 답한다
        // (`QuoteChatSmallTalk`, `QuoteChatAuthorFacts` 의 설명).
        if let canned = QuoteChatAppAnswer.reply(to: question, language: language, context: context) {
            return AsyncThrowingStream { continuation in
                continuation.yield(canned)
                continuation.finish()
            }
        }
        let recap = Self.isFollowUp(question) ? Self.recap(of: messages) : []
        // 명언 본문을 그대로 돌려준 답도 답이 아니다(1.15.6 점검: "비슷한 다른 명언?" 에 명언 그대로).
        let earlierReplies = messages.filter { $0.role == .assistant }.map(\.text)
            + (context.map { [$0.quote.text] } ?? [])

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    // 말풍선에는 사용자가 쓴 그대로 남고, 모델에게만 명언·언어 지시·`/no_think` 가 붙는다.
                    // 첫 답이 앱 언어가 아니면 **더 강한 지시로 한 번** 다시 시킨다.
                    var lastRejection: ReplyLanguageGuard.Rejection = .wrongLanguage
                    for strict in [false, true] {
                        self.service.resetSession()
                        let prompt = QuoteChatPrompt.localPrompt(
                            question: question, language: language, context: context,
                            strict: strict, recap: recap
                        )
                        let rejection = try await self.attempt(
                            system: system, prompt: prompt, question: question,
                            earlierReplies: earlierReplies, language: language, into: continuation
                        )
                        guard let rejection else {
                            continuation.finish()
                            return
                        }
                        lastRejection = rejection
                    }
                    continuation.finish(throwing: lastRejection == .wrongLanguage
                        ? QuoteChatError.wrongLanguage : QuoteChatError.unusableReply)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 한 번 시도한다. 받아들였으면 nil, 버렸으면 그 이유.
    /// 버린 답은 **화면에 한 글자도 나가지 않았다**(가드가 앞부분을 쥐고 있었다).
    private func attempt(
        system: String,
        prompt: String,
        question: String,
        earlierReplies: [String],
        language: AppLanguage,
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> ReplyLanguageGuard.Rejection? {
        var replyGuard = ReplyLanguageGuard(expected: language, question: question, earlierReplies: earlierReplies)
        for try await chunk in service.stream(model: model, system: system, prompt: prompt) {
            switch replyGuard.feed(chunk) {
            case .hold:
                continue
            case .release(let text):
                continuation.yield(text)
            case .reject:
                return replyGuard.rejection ?? .wrongLanguage
            }
        }
        switch replyGuard.finish() {
        case .hold:
            return nil
        case .release(let text):
            if !text.isEmpty { continuation.yield(text) }
            return nil
        case .reject:
            return replyGuard.rejection ?? .wrongLanguage
        }
    }

    /// 앞 질문을 이어 받는 말인지. **이어 받을 때만** 앞 질문을 적어 준다.
    ///
    /// 1.15.6 점검: 앞 질문을 늘 적어 주었더니 `지금 내 상황에 어떻게 적용할까?` 에
    /// 바로 앞 질문(`작가는 어느 나라 사람이야?`)의 답을 했다. 작은 모델은 목록의 마지막
    /// 질문에 답해 버린다. `더 쉽게 설명해 줘` 처럼 가리키는 말이 있는 짧은 질문에만 붙인다.
    nonisolated static func isFollowUp(_ question: String) -> Bool {
        let text = question.lowercased()
        guard ReplyLanguageGuard.normalized(text).count <= 25 else { return false }
        let markers = ["더 ", "더쉽", "다시", "쉽게", "자세히", "자세하게", "그거", "그건", "그게", "그럼", "그래서",
                       "방금", "위에", "앞에", "예를", "예시", "요약", "무슨 말",
                       "再", "更", "简单", "簡單", "详细", "詳細", "刚才", "剛才", "例子", "总结", "總結"]
        if markers.contains(where: { text.contains($0) }) { return true }
        let words = Set(text.split(whereSeparator: { !$0.isLetter }).map(String.init))
        return !words.isDisjoint(with: ["more", "again", "simpler", "simply", "that", "it", "example", "summarize", "elaborate"])
    }

    /// 질문 옆에 적어 줄 앞선 **질문**. 최근 두 개, 한 개당 120자까지.
    ///
    /// **모델의 앞 답은 넣지 않는다.** 1.15.5 에서 앞 답까지 적어 주었더니 1.7B 가
    /// "야는 랠프 월도 에머슨의 친구야." 를 `ㅋㅋㅋ`·`홀롤ㅗ`·`작가의 일생을 알려 줘` 에
    /// 그대로 베꼈다. 적힌 답은 작은 모델에게 "이렇게 답하라" 로 읽힌다. 앞 질문만 있어도
    /// "더 쉽게 설명해 줘" 가 무엇을 가리키는지는 안다. 앱이 답한 일상 말은 빼고,
    /// 지금 하는 질문도 뺀다.
    nonisolated static func recap(of messages: [QuoteChatMessage], turns: Int = 2, limit: Int = 120) -> [String] {
        var questions = messages.filter { $0.role == .user }.map { $0.text.trimmed }
        if messages.last?.role == .user, !questions.isEmpty { questions.removeLast() }
        let meaningful = questions.filter {
            !$0.isEmpty && QuoteChatSmallTalk.classify($0) == nil && QuoteChatAuthorFacts.classify($0) == nil
        }
        return meaningful.suffix(turns).map { String($0.prefix(limit)) }
    }
}
