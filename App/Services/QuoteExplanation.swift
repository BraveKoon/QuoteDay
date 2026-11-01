import Foundation

/// 기기에서 만든 명언 해설 한 편.
///
/// 세 부분으로 나눈 이유는 읽는 사람의 목적이 다르기 때문이다.
/// - `summary`  : 무슨 말인지 한 번에 잡아 준다. 바쁘면 여기까지만 읽어도 된다.
/// - `context`  : 이 문장이 나온 상황과 인물. 왜 이 말이 무거운지 알려 준다.
/// - `practice` : 오늘 해 볼 수 있는 구체적인 한 가지. 읽고 끝나지 않게 한다.
///
/// 해설은 **AI 가 만든 글**이므로 화면에서 반드시 그 사실을 밝힌다.
/// (`QuoteExplanation.isGenerated`)
public struct QuoteExplanation: Codable, Hashable, Sendable {
    public let summary: String
    public let context: String
    public let practice: String

    public init(summary: String, context: String, practice: String) {
        self.summary = summary
        self.context = context
        self.practice = practice
    }

    /// 이 해설을 만든 엔진의 이름. 화면 표기에 쓴다.
    public static let engineName = L("온디바이스 AI")

    /// 세 칸이 모두 비어 있지 않은지. 부분 생성 도중에는 비어 있을 수 있다.
    public var isComplete: Bool {
        !summary.trimmed.isEmpty && !context.trimmed.isEmpty && !practice.trimmed.isEmpty
    }

    /// 화면에 보여 줄 칸 하나.
    ///
    /// 튜플 대신 구조체를 쓰는 이유: `ForEach(..., id: \.kind)` 처럼 키패스를
    /// 쓰려면 타입이 필요하다. Swift 는 튜플 원소를 가리키는 키패스를 만들지 못한다.
    public struct Part: Identifiable, Hashable, Sendable {
        public let kind: Section
        public let text: String
        public var id: Section { kind }
    }

    /// 화면에 보여 줄 칸들. 비어 있는 칸은 건너뛴다.
    public var sections: [Part] {
        var result: [Part] = []
        if !summary.trimmed.isEmpty { result.append(Part(kind: .summary, text: summary.trimmed)) }
        if !context.trimmed.isEmpty { result.append(Part(kind: .context, text: context.trimmed)) }
        if !practice.trimmed.isEmpty { result.append(Part(kind: .practice, text: practice.trimmed)) }
        return result
    }

    public enum Section: String, Codable, Hashable, Sendable, CaseIterable {
        case summary, context, practice

        /// 화면 제목. `L(...)` 를 거쳐 앱 언어로 나온다.
        public var title: String {
            switch self {
            case .summary: L("무슨 뜻인가요")
            case .context: L("어떤 배경인가요")
            case .practice: L("오늘 해 볼 일")
            }
        }

        public var symbol: String {
            switch self {
            case .summary: "text.quote"
            case .context: "book.closed"
            case .practice: "figure.walk"
            }
        }
    }
}

/// 해설을 만드는 쪽이 지켜야 할 약속.
///
/// 화면은 이 프로토콜만 알기 때문에, 기기 모델이 없는 곳(시뮬레이터·테스트)에서도
/// 같은 화면을 그려 볼 수 있다.
@MainActor
public protocol QuoteExplaining: AnyObject {
    /// 지금 이 기기에서, 이 언어로 해설을 만들 수 있는지.
    ///
    /// 언어마다 지원 여부가 다르다(기기 모델은 처음에 일부 언어만 지원했다).
    /// 그래서 `var` 가 아니라 언어를 받는 함수다. 앱 언어를 바꾸면 화면도
    /// 버튼과 안내 사이를 오갈 수 있어야 한다.
    func availability(for language: AppLanguage) -> QuoteExplainerAvailability

    /// 한 명언의 해설을 만든다. 조각이 도착할 때마다 `onUpdate` 가 불린다.
    ///
    /// - Parameters:
    ///   - quote: 해설할 명언 (이미 앱 언어로 번역된 사본).
    ///   - author: 명언을 남긴 인물.
    ///   - language: 해설을 쓸 언어.
    ///   - onUpdate: 부분 결과. 여러 번, 최대한 빠르게 불린다.
    /// - Returns: 완성된 해설.
    @discardableResult
    func explain(
        quote: Quote,
        author: Author,
        language: AppLanguage,
        onUpdate: @escaping @MainActor (QuoteExplanation) -> Void
    ) async throws -> QuoteExplanation
}

/// 해설을 만들 수 있는지에 대한 판단.
///
/// 화면은 이 값을 보고 **버튼을 그릴지, 안내 문구를 그릴지**를 정한다.
/// (확정 사양: 미지원 기기는 기능을 숨기지 않고 안내를 보여 준다.)
public enum QuoteExplainerAvailability: Equatable, Sendable {
    /// 지금 만들 수 있다.
    case available
    /// OS 가 너무 낮다. (iOS 26 미만)
    case requiresNewerOS
    /// 기기는 되지만 Apple Intelligence 가 꺼져 있다.
    case appleIntelligenceDisabled
    /// 기기가 Apple Intelligence 대상이 아니다.
    case deviceNotEligible
    /// 모델을 내려받는 중이라 아직 준비되지 않았다.
    case modelNotReady
    /// 한국어를 지원하지 않는 등, 이 언어로는 만들 수 없다.
    case unsupportedLanguage(AppLanguage)

    public var canExplain: Bool { self == .available }

    /// 왜 지금 쓸 수 없는지 한 줄로. 쓸 수 있으면 nil.
    public var explanation: String? {
        switch self {
        case .available:
            nil
        case .requiresNewerOS:
            L("iOS 26 이상에서 쓸 수 있어요.")
        case .appleIntelligenceDisabled:
            L("설정에서 Apple Intelligence 를 켜면 쓸 수 있어요.")
        case .deviceNotEligible:
            L("이 기기에서는 Apple Intelligence 를 쓸 수 없어요.")
        case .modelNotReady:
            L("AI 모델을 준비하는 중이에요. 잠시 뒤 다시 열어 주세요.")
        case .unsupportedLanguage:
            L("이 언어로는 아직 해설을 만들 수 없어요.")
        }
    }

    /// 설정 앱으로 보내야 하는 경우. 화면이 안내와 함께 링크를 그린다.
    public var settingsURL: URL? {
        switch self {
        case .appleIntelligenceDisabled:
            URL(string: "App-Prefs:root=APPLE_ACCOUNT&path=APPLE_INTELLIGENCE")
        default:
            nil
        }
    }
}

/// 문자열 다듬기 도우미. (`trimmed` 는 여러 곳에서 쓴다)
extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
