import Foundation
import Observation

/// 대화의 상태와 흐름을 맡는다.
///
/// 화면(뷰)이 전송·스트리밍·오류를 직접 다루면 상태가 여기저기 흩어진다.
/// "지금 답하는 중인가", "무엇을 실패했나", "무엇이 남았나"를 한곳에서만
/// 관리하면 화면은 그리기만 하면 된다.
///
/// 대화는 **기기에 저장하지 않는다.** 명언·인물 정보는 이미 공개된 데이터지만
/// 사용자가 쓴 질문에는 사적인 내용이 섞인다. 앱을 끄면 사라지는 편이 낫다.
@MainActor
@Observable
public final class QuoteChatEngine {

    private(set) var messages: [QuoteChatMessage] = []
    private(set) var isSending = false
    /// 마지막 실패. 화면이 배너로 보여 준다.
    private(set) var errorMessage: String?
    /// 지금 답하고 있는 통로의 이름. 화면 위쪽 배지에 쓴다.
    private(set) var activeProviderTitle: String?

    /// 통로를 만드는 방법. 테스트에서는 가짜를 끼워 넣는다.
    @ObservationIgnored private let makeTransport: @MainActor (AIChatSettings) -> QuoteChatTransport?
    @ObservationIgnored private let onDeviceTransport = OnDeviceChatTransport()
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(
        makeTransport: (@MainActor (AIChatSettings) -> QuoteChatTransport?)? = nil
    ) {
        self.makeTransport = makeTransport ?? Self.defaultTransport
    }

    private static func defaultTransport(_ settings: AIChatSettings) -> QuoteChatTransport? {
        switch settings.provider {
        case .onDevice:
            return nil // 엔진이 들고 있는 OnDeviceChatTransport 를 쓴다.
        case .localQwen:
            return LocalQwenChatTransport(model: settings.localModel)
        }
    }

    // MARK: - 보내기

    /// 질문을 보내고 답을 스트리밍으로 받는다.
    public func send(
        _ text: String,
        context: QuoteChatContext?,
        settings: AIChatSettings,
        language: AppLanguage
    ) {
        let question = text.trimmed
        guard !question.isEmpty, !isSending else { return }

        // 보내기 **전에** 지금 통로를 쓸 수 있는지 본다. 못 쓰는데 질문을 넣으면
        // 빈 말풍선만 남고, 사용자는 무엇이 잘못됐는지 모른다.
        switch settings.availability {
        case .ready:
            break
        case .unavailable(let reason):
            fail(QuoteChatError.onDeviceUnavailable(reason))
            return
        case .needsDownload(let model):
            fail(QuoteChatError.localModelMissing(model))
            return
        case .localUnsupportedDevice:
            fail(QuoteChatError.localNotOnSimulator)
            return
        }

        let transport: QuoteChatTransport
        switch settings.provider {
        case .onDevice:
            onDeviceTransport.resetIfContextChanged(context?.quote.slug)
            transport = onDeviceTransport
        case .localQwen:
            // 기기 내 모델은 세션이 문맥을 들고 있다. 지침(명언)이 바뀌면
            // 서비스가 알아서 새 세션을 만든다.
            guard let made = makeTransport(settings) else {
                fail(QuoteChatError.localModelMissing(settings.localModel))
                return
            }
            transport = made
        }

        errorMessage = nil
        messages.append(QuoteChatMessage(role: .user, text: question))
        messages.append(QuoteChatMessage(role: .assistant, text: "", isStreaming: true))

        let system = systemPrompt(context: context, language: language)
        activeProviderTitle = settings.provider.title
        isSending = true

        let history = messages.dropLast() // 방금 넣은 빈 답변은 빼고 보낸다.
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var received = false
                let stream = transport.stream(
                    system: system,
                    messages: Array(history),
                    language: language,
                    context: context
                )
                for try await delta in stream {
                    received = true
                    self.appendDelta(delta, isSnapshot: transport.yieldsSnapshots)
                }
                if !received, self.messages.last?.text.isEmpty == true {
                    throw QuoteChatError.emptyReply
                }
                self.finishStreaming()
            } catch is CancellationError {
                self.finishStreaming()
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? L("답을 받지 못했어요. 잠시 뒤 다시 시도해 주세요.")
                self.fail(error, message: message)
            }
        }
    }

    /// 답을 그만 받는다. 지금까지 받은 글자는 남긴다(사용자가 읽던 중이다).
    public func stop() {
        task?.cancel()
        task = nil
        isSending = false
        finishStreaming()
    }

    /// 대화를 비운다.
    public func clear() {
        task?.cancel()
        task = nil
        isSending = false
        errorMessage = nil
        activeProviderTitle = nil
        messages.removeAll()
        onDeviceTransport.reset()
        LocalQwenService.shared.resetSession()
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: - 내부

    private func systemPrompt(context: QuoteChatContext?, language: AppLanguage) -> String {
        QuoteChatPrompt.system(context: context, language: language)
    }

    /// 조각을 답 말풍선에 합친다.
    ///
    /// 온디바이스 모델은 조각마다 **전체 글**을 준다(스냅숏) — 더 긴 쪽이 이긴다.
    /// Qwen 은 **이어붙일 조각**을 준다(델타) — 무조건 붙인다. 통로가 어느 쪽인지
    /// 밝히므로 추측하지 않는다. 델타를 "지금까지의 글 앞부분과 같다"는 이유로
    /// 버리면 `이`·`그` 처럼 글머리와 같은 조각이 사라진다.
    private func appendDelta(_ delta: String, isSnapshot: Bool) {
        guard let index = messages.lastIndex(where: { $0.role == .assistant }) else { return }
        guard isSnapshot else {
            messages[index].text += delta
            return
        }
        let current = messages[index].text
        if delta.count > current.count, delta.hasPrefix(current) {
            messages[index].text = delta
        } else if !current.hasPrefix(delta) {
            // 앞부분이 이어지지 않는 스냅숏은 새 글로 본다.
            messages[index].text = delta
        }
        // 같거나 더 짧은 스냅숏은 무시한다.
    }

    private func finishStreaming() {
        if let index = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[index].isStreaming = false
            // 아무것도 못 받았으면 빈 말풍선을 남기지 않는다.
            if messages[index].text.trimmed.isEmpty {
                messages.remove(at: index)
            }
        }
        isSending = false
        task = nil
    }

    private func fail(_ error: Error, message: String? = nil) {
        let text = message
            ?? (error as? LocalizedError)?.errorDescription
            ?? L("답을 받지 못했어요. 잠시 뒤 다시 시도해 주세요.")
        errorMessage = text
        AppLog.aiChat.error("대화 실패: \(String(describing: type(of: error)), privacy: .public)")
        // 실패한 빈 말풍선은 지우고, 방금 보낸 질문은 남긴다(다시 보낼 수 있게).
        if let index = messages.lastIndex(where: { $0.role == .assistant }),
           messages[index].text.trimmed.isEmpty {
            messages.remove(at: index)
        }
        isSending = false
        task = nil
    }
}
