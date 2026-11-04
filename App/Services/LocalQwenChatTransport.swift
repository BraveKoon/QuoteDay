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
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error> {
        // 기기 내 모델은 **자기 세션이 대화를 기억한다.** 그래서 매번 전체 대화를
        // 다시 넣지 않고 마지막 질문만 보낸다 — 넣으면 같은 말이 두 번 들어간다.
        let prompt = messages.last(where: { $0.role == .user })?.text.trimmed ?? ""
        guard !prompt.isEmpty else {
            return AsyncThrowingStream { $0.finish() }
        }
        // 말풍선에는 사용자가 쓴 그대로 남고, 모델에게만 언어 지시와 `/no_think` 가 붙는다.
        let sent = QuoteChatPrompt.localPrompt(question: prompt, language: language)
        return service.stream(model: model, system: system, prompt: sent)
    }
}
