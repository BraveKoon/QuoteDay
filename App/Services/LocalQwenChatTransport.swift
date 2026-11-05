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
        // 기기 내 모델은 **자기 세션이 대화를 기억한다.** 그래서 매번 전체 대화를
        // 다시 넣지 않고 마지막 질문만 보낸다 — 넣으면 같은 말이 두 번 들어간다.
        let question = messages.last(where: { $0.role == .user })?.text.trimmed ?? ""
        guard !question.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    // 말풍선에는 사용자가 쓴 그대로 남고, 모델에게만 명언·언어 지시·`/no_think` 가 붙는다.
                    // 첫 답이 앱 언어가 아니면 **더 강한 지시로 한 번** 다시 시킨다.
                    for strict in [false, true] {
                        let prompt = QuoteChatPrompt.localPrompt(
                            question: question, language: language, context: context, strict: strict
                        )
                        if try await self.attempt(
                            system: system, prompt: prompt, language: language, into: continuation
                        ) {
                            continuation.finish()
                            return
                        }
                        // 틀린 언어의 답이 대화 기록에 남으면 이어지는 답도 그것을 따라 한다.
                        // 세션을 비워 그 답이 문맥에 들어가지 않게 한다.
                        self.service.resetSession()
                    }
                    continuation.finish(throwing: QuoteChatError.wrongLanguage)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 한 번 시도한다. 앱 언어로 답했으면 true, 틀린 언어로 시작해서 버렸으면 false.
    /// 버린 답은 **화면에 한 글자도 나가지 않았다**(가드가 앞부분을 쥐고 있었다).
    private func attempt(
        system: String,
        prompt: String,
        language: AppLanguage,
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> Bool {
        var replyGuard = ReplyLanguageGuard(expected: language)
        for try await chunk in service.stream(model: model, system: system, prompt: prompt) {
            switch replyGuard.feed(chunk) {
            case .hold:
                continue
            case .release(let text):
                continuation.yield(text)
            case .reject:
                return false
            }
        }
        switch replyGuard.finish() {
        case .hold:
            return true
        case .release(let text):
            if !text.isEmpty { continuation.yield(text) }
            return true
        case .reject:
            return false
        }
    }
}
