import Foundation
import Observation

/// AI 대화 설정 — 어디에 물을지, 어떤 모델을 쓸지, 열쇠가 있는지.
///
/// **키만 Keychain 에 두고 나머지는 `UserDefaults`** 에 둔다. 키는 비밀이고,
/// 모델 이름·지역은 비밀이 아니기 때문이다. 키는 화면에도 값으로 되돌려 주지
/// 않는다(`hasKey` 만 알려 준다) — 실수로 어깨너머로 보이거나 로그에 남는 일을
/// 막기 위해서다.
@MainActor
@Observable
public final class AIChatSettings {

    /// Keychain 에 넣을 때 쓰는 이름.
    enum Keychain {
        static let service = "com.quoteday.QuoteDay.aichat"
        static let account = "dashscope-api-key"
    }

    private static let providerKey = "aiChat.provider"
    private static let regionKey = "aiChat.qwenRegion"
    private static let modelKey = "aiChat.qwenModel"

    /// Qwen 모델 목록. 쓰임이 다르다.
    public enum QwenModel: String, CaseIterable, Identifiable, Sendable {
        case plus = "qwen-plus"
        case max = "qwen-max"
        case flash = "qwen-flash"

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .plus: "qwen-plus"
            case .max: "qwen-max"
            case .flash: "qwen-flash"
            }
        }

        public var detail: String {
            switch self {
            case .plus: L("균형형. 대화용으로 무난해요.")
            case .max: L("가장 똑똑하지만 느리고 비싸요.")
            case .flash: L("가장 빠르고 저렴해요. 답이 짧아요.")
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    /// 온디바이스 모델의 가용성만 물어보는 데 쓴다. 세션을 만들지 않는다.
    @ObservationIgnored private let deviceExplainer = FoundationModelsQuoteExplainer()

    public var provider: AIChatProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Self.providerKey)
            access(keyPath: \.provider)
        }
    }

    public var region: QwenRegion {
        didSet {
            defaults.set(region.rawValue, forKey: Self.regionKey)
            access(keyPath: \.region)
        }
    }

    public var model: QwenModel {
        didSet {
            defaults.set(model.rawValue, forKey: Self.modelKey)
            access(keyPath: \.model)
        }
    }

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.provider = AIChatProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "")
            ?? .onDevice
        self.region = QwenRegion(rawValue: defaults.string(forKey: Self.regionKey) ?? "")
            ?? .international
        self.model = QwenModel(rawValue: defaults.string(forKey: Self.modelKey) ?? "")
            ?? .plus
    }

    // MARK: - 키

    /// 키가 저장되어 있는지. 값 자체는 화면에 주지 않는다.
    public var hasKey: Bool { !(apiKey ?? "").isEmpty }

    /// 실제 키. 네트워크 요청을 만들 때만 쓴다. 화면에 바인딩하지 않는다.
    var apiKey: String? {
        KeychainStore.get(for: Keychain.account, service: Keychain.service)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 키를 저장한다. 공백·줄바꿈은 지운다(붙여 넣을 때 흔히 딸려 온다).
    @discardableResult
    public func saveKey(_ raw: String) -> Bool {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        do {
            try KeychainStore.set(cleaned, for: Keychain.account, service: Keychain.service)
            access(keyPath: \.hasKey)
            return true
        } catch {
            AppLog.aiChat.error("AI 키를 저장하지 못했습니다.")
            return false
        }
    }

    public func deleteKey() {
        KeychainStore.delete(for: Keychain.account, service: Keychain.service)
        access(keyPath: \.hasKey)
    }

    /// 지금 설정으로 대화할 수 있는지. 못 하면 이유.
    public var availability: AIChatAvailability {
        switch provider {
        case .onDevice:
            let reason = deviceExplainer.availability(for: Localization.language)
            return reason.canExplain ? .ready : .unavailable(reason)
        case .qwen:
            if !hasKey { return .needsKey }
            return region.chatURL == nil ? .misconfigured : .ready
        }
    }
}

/// 대화를 지금 시작할 수 있는지.
public enum AIChatAvailability: Equatable, Sendable {
    case ready
    /// Qwen 을 골랐는데 키가 없다.
    case needsKey
    /// 온디바이스 모델을 쓸 수 없다.
    case unavailable(QuoteExplainerAvailability)
    /// 주소가 잘못됐다(있을 수 없지만 방어).
    case misconfigured

    public var canChat: Bool { self == .ready }
}
