import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Foundation Models 로 대화한다. **기기 안에서만** 돈다.
///
/// 해설 카드(`FoundationModelsQuoteExplainer`)와 같은 엔진이지만 쓰임이 다르다.
/// 해설은 정해진 세 칸을 채우고, 여기서는 사용자가 무엇을 물어도 받아야 한다.
/// 그래서 자유 문장 스트림(`streamResponse(to:)`)을 쓴다.
///
/// 세션은 대화가 이어지는 동안 유지한다. 매번 새로 만들면 모델을 메모리에
/// 다시 올리는 비용이 붙고, 앞서 나눈 말을 잊는다.
@MainActor
public final class OnDeviceChatTransport: QuoteChatTransport {

    private var session: AnyObject?
    private var language: AppLanguage?
    private var instructions: String?
    /// 지금 대화가 다루는 명언. 바뀌면 세션을 새로 연다.
    private var contextSlug: String?

    public init() {}

    /// 대화를 처음부터 다시 시작한다. (새 대화 버튼)
    public func reset() {
        session = nil
        instructions = nil
        language = nil
        contextSlug = nil
    }

    /// 다루는 명언이 바뀌면 앞선 대화를 이어 갈 수 없다.
    ///
    /// 같은 세션에 다른 명언 이야기를 섞으면 "이 명언"이 무엇인지 흐려지고,
    /// 세션 기록이 문맥 한도를 잡아먹는다.
    public func resetIfContextChanged(_ slug: String?) {
        guard contextSlug != slug else { return }
        reset()
        contextSlug = slug
    }

    /// Foundation Models 는 조각마다 지금까지의 전체 글을 준다.
    public var yieldsSnapshots: Bool { true }

    public func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage,
        context: QuoteChatContext?
    ) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return streamModern(system: system, messages: messages, language: language)
        }
        #endif
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: QuoteChatError.onDeviceUnavailable(.requiresNewerOS))
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func streamModern(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let model = SystemLanguageModel.default
                    if case .available = model.availability {
                        // 쓸 수 있다.
                    } else {
                        let reason = FoundationModelsQuoteExplainer().availability(for: language)
                        throw QuoteChatError.onDeviceUnavailable(reason)
                    }

                    // 지시문이나 언어가 바뀌면 세션을 새로 만든다.
                    // (지시문은 세션을 만들 때 고정된다.)
                    let session = self.session(for: system, language: language)

                    // 마지막 사용자 발화를 보낸다. 앞선 대화는 세션 기록에 있다.
                    guard let lastUser = messages.last(where: { $0.role == .user }) else {
                        continuation.finish()
                        return
                    }

                    let stream = session.streamResponse(to: lastUser.text)
                    for try await snapshot in stream {
                        if Task.isCancelled { break }
                        let text = snapshot.content
                        if !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch let error as QuoteChatError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: QuoteChatError.onDeviceFailed(error.localizedDescription)
                    )
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @available(iOS 26.0, *)
    private func session(for system: String, language: AppLanguage) -> LanguageModelSession {
        if let existing = session as? LanguageModelSession,
           self.instructions == system,
           self.language == language {
            return existing
        }
        let created = LanguageModelSession(instructions: system)
        session = created
        instructions = system
        self.language = language
        return created
    }
    #endif
}
