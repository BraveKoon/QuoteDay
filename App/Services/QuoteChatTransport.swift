import Foundation

/// 대화 한 줄.
public struct QuoteChatMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public var text: String
    /// 지금 글자가 흘러 들어오는 중인지. 화면이 커서를 깜빡인다.
    public var isStreaming: Bool

    public init(id: UUID = UUID(), role: Role, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }
}

/// 대화가 실패한 이유. 화면에 그대로 쓸 수 있는 문장을 들고 다닌다.
///
/// 클라우드 통로를 걷어내면서 키·서버·네트워크 오류도 함께 사라졌다. 지금
/// 실패할 수 있는 곳은 기기 안뿐이다: 모델이 없거나, 못 올리거나, 이 환경에서
/// 돌릴 수 없거나, 답이 비어 있는 경우.
public enum QuoteChatError: LocalizedError, Equatable {
    /// 이 기기에서 온디바이스 모델을 쓸 수 없다.
    case onDeviceUnavailable(QuoteExplainerAvailability)
    /// 기기 내 모델을 아직 받지 않았다.
    case localModelMissing(LocalQwenModel)
    /// 시뮬레이터에서는 MLX(Metal)를 쓸 수 없다.
    case localNotOnSimulator
    /// 내려받기·적재가 실패했다.
    case localModelFailed(String)
    /// 답이 한 글자도 오지 않았다.
    case emptyReply

    public var errorDescription: String? {
        switch self {
        case .onDeviceUnavailable(let reason):
            reason.explanation ?? L("이 기기에서는 온디바이스 AI 를 쓸 수 없어요.")
        case .localModelMissing(let model):
            L("기기 내 %@ 모델을 아직 받지 않았어요. 설정에서 내려받아 주세요.", model.title)
        case .localNotOnSimulator:
            L("시뮬레이터에서는 기기 내 AI 를 돌릴 수 없어요. 실제 기기에서 확인해 주세요.")
        case .localModelFailed(let reason):
            L("모델을 준비하지 못했어요: %@", reason)
        case .emptyReply:
            L("답이 오지 않았어요. 다시 물어봐 주세요.")
        }
    }
}

/// 모델에게 말을 거는 통로.
///
/// 두 통로(Apple Foundation Models · 기기 내 Qwen3)가 하는 일은 같다:
/// 지금까지의 대화를 주고 다음 말을 **조각조각** 받는다. 그래서 화면은 어느 쪽을
/// 쓰는지 몰라도 된다.
@MainActor
public protocol QuoteChatTransport {
    /// 조각의 흐름. 오류도 이 흐름을 통해 온다.
    func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error>
}
