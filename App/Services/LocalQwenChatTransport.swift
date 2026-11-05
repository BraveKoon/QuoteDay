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
        // 그래서 앞선 대화는 **골라서 짧게** 질문 옆에 적어 준다(`localPrompt` 의 recap).
        // 지침을 매번 다시 읽히는 값(1.7B 에서 1~2초)이 대화가 통째로 망가지는 것보다 싸다.
        let question = messages.last(where: { $0.role == .user })?.text.trimmed ?? ""
        let recap = Self.recap(of: messages)
        guard !question.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

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
                            language: language, into: continuation
                        )
                        guard let rejection else {
                            continuation.finish()
                            return
                        }
                        lastRejection = rejection
                    }
                    continuation.finish(throwing: lastRejection == .echo
                        ? QuoteChatError.emptyReply : QuoteChatError.wrongLanguage)
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
        language: AppLanguage,
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> ReplyLanguageGuard.Rejection? {
        var replyGuard = ReplyLanguageGuard(expected: language, question: question)
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

    /// 질문 옆에 적어 줄 앞선 대화. **최근 두 번의 주고받기만**, 한 마디당 120자까지.
    ///
    /// 무너진 답은 빼고 적는다 — 질문을 되받은 답, 아주 짧은 답이 기록에 들어가면 모델이
    /// 그것을 베낀다. 지금 하는 질문(마지막 사용자 말)과 비어 있는 답 자리는 넣지 않는다.
    nonisolated static func recap(of messages: [QuoteChatMessage], turns: Int = 2, limit: Int = 120) -> [QuoteChatMessage] {
        var history = messages
        if let last = history.last, last.role == .user { history.removeLast() }

        var pairs: [(QuoteChatMessage, QuoteChatMessage)] = []
        var index = 0
        while index + 1 < history.count {
            let user = history[index], reply = history[index + 1]
            if user.role == .user, reply.role == .assistant {
                pairs.append((user, reply))
                index += 2
            } else {
                index += 1
            }
        }

        let usable = pairs.filter { user, reply in
            let answer = ReplyLanguageGuard.normalized(reply.text)
            return ReplyLanguageGuard.letters(in: reply.text) >= ReplyLanguageGuard.shortReplyThreshold
                && answer != ReplyLanguageGuard.normalized(user.text)
        }
        return usable.suffix(turns).flatMap { user, reply in
            [QuoteChatMessage(role: .user, text: String(user.text.trimmed.prefix(limit))),
             QuoteChatMessage(role: .assistant, text: String(reply.text.trimmed.prefix(limit)))]
        }
    }
}
