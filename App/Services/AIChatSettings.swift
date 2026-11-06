import Foundation
import Observation

/// AI 대화 설정 — 어디에 물을지, 기기 내 모델을 어느 크기로 쓸지.
///
/// 저장할 것이 **비밀도 아니고 작다**: 고른 통로와 모델 크기뿐이라
/// `UserDefaults` 로 충분하다. 클라우드 통로(사용자 API 키)를 걷어내면서
/// Keychain 을 쓸 이유도 함께 사라졌다.
@MainActor
@Observable
public final class AIChatSettings {

    private static let providerKey = "aiChat.provider"
    private static let localChoiceKey = "aiChat.localChoice"

    @ObservationIgnored private let defaults: UserDefaults
    /// 기기 내 모델을 받아 두었는지 물어보는 곳. 내려받기 자체는 여기서 하지 않는다.
    @ObservationIgnored private let localService: LocalQwenService
    /// 온디바이스 모델의 가용성만 물어보는 데 쓴다. 세션을 만들지 않는다.
    @ObservationIgnored private let deviceExplainer = FoundationModelsQuoteExplainer()

    public var provider: AIChatProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Self.providerKey)
            access(keyPath: \.provider)
        }
    }

    /// 기기 내 Qwen 을 쓸 때 어느 크기를 쓸지.
    public var localChoice: LocalQwenChoice {
        didSet {
            defaults.set(localChoice.rawValue, forKey: Self.localChoiceKey)
            access(keyPath: \.localChoice)
        }
    }

    public init(defaults: UserDefaults = AppGroup.defaults, localService: LocalQwenService? = nil) {
        self.defaults = defaults
        self.localService = localService ?? .shared
        self.provider = AIChatProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "")
            ?? .onDevice
        self.localChoice = LocalQwenChoice(rawValue: defaults.string(forKey: Self.localChoiceKey) ?? "")
            ?? .automatic
    }

    /// 지금 설정으로 대화할 수 있는지. 못 하면 이유.
    public var availability: AIChatAvailability {
        switch provider {
        case .onDevice:
            let reason = deviceExplainer.availability(for: Localization.language)
            return reason.canExplain ? .ready : .unavailable(reason)
        case .localQwen:
            guard localService.canRun else { return .localUnsupportedDevice }
            let model = localModel
            guard localService.isDownloaded(model) else { return .needsDownload(model) }
            return .ready
        }
    }

    /// 기기 내 Qwen 에 실제로 쓸 모델.
    ///
    /// 고른 크기가 아직 없는데 **다른 크기가 이미 있으면** 있는 쪽을 쓴다(여럿이면 가장 큰 것).
    /// 이미 받아 둔 것을 두고 또 1GB 를 받게 하는 것은 무례하다. 자동 추천이 4B 로 바뀌어도
    /// 1.7B 를 받아 둔 사람은 그대로 1.7B 로 대화한다 — 4B 는 설정에서 직접 받는다.
    public var localModel: LocalQwenModel {
        let wanted = localChoice.resolve()
        if localService.isDownloaded(wanted) { return wanted }
        if let ready = LocalQwenModel.allCases.last(where: { localService.isDownloaded($0) }) {
            return ready
        }
        return wanted
    }
}

/// 대화를 지금 시작할 수 있는지.
public enum AIChatAvailability: Equatable, Sendable {
    case ready
    /// 온디바이스 모델을 쓸 수 없다.
    case unavailable(QuoteExplainerAvailability)
    /// 기기 내 Qwen 을 아직 받지 않았다.
    case needsDownload(LocalQwenModel)
    /// 시뮬레이터처럼 MLX 를 돌릴 수 없는 환경.
    case localUnsupportedDevice

    public var canChat: Bool { self == .ready }
}
