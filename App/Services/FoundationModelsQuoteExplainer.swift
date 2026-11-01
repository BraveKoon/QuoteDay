import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// 해설을 만들다가 생긴 문제. 화면에 보여 줄 문장을 들고 다닌다.
public enum QuoteExplainerError: LocalizedError {
    /// 이 기기·이 언어로는 만들 수 없다.
    case unavailable(QuoteExplainerAvailability)
    /// 모델이 답을 만들지 못했다(안전 정책·문맥 초과·일시적 오류).
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let availability):
            availability.explanation
        case .generationFailed:
            L("해설을 만들지 못했어요. 잠시 뒤 다시 시도해 주세요.")
        }
    }
}

/// **온디바이스** Apple Foundation Models 로 명언을 해설한다.
///
/// 왜 클라우드가 아니라 기기 모델인가:
/// - 명언과 인물 정보가 기기 밖으로 나가지 않는다.
/// - 서버 비용이 없어 **무료 기능**으로 둘 수 있다.
/// - 비행기 모드에서도 동작한다.
///
/// 대신 기기와 OS 를 가린다. iOS 26 미만이거나 Apple Intelligence 대상이 아닌
/// 기기에서는 만들 수 없으므로, 화면은 `availability(for:)` 를 보고 안내를
/// 보여 준다(기능을 숨기지 않는다 — 확정 사양).
///
/// 배포 타깃이 iOS 17 이라 `#if canImport(FoundationModels)` + `@available` 로
/// 감싼다. 예전 OS 에서 빌드해도 이 파일은 빈 껍데기가 되고 앱은 그대로 동작한다.
@MainActor
public final class FoundationModelsQuoteExplainer: QuoteExplaining {

    /// 언어별 세션을 하나씩 들고 있는다.
    ///
    /// 세션을 매번 새로 만들면 모델을 메모리에 다시 올리는 비용이 붙는다.
    /// 지시문이 언어마다 다르므로 언어별로 하나씩만 둔다.
    private var sessions: [AppLanguage: AnyObject] = [:]

    public init() {}

    // MARK: - 쓸 수 있는지

    public func availability(for language: AppLanguage) -> QuoteExplainerAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return Self.currentAvailability(for: language)
        }
        return .requiresNewerOS
        #else
        return .requiresNewerOS
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func currentAvailability(for language: AppLanguage) -> QuoteExplainerAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            // 언어 지원은 별개다. 처음에는 영어만 되던 시절도 있었다.
            let wanted = language.locale.language.languageCode?.identifier ?? language.rawValue
            let supported = model.supportedLanguages.contains { candidate in
                (candidate.languageCode?.identifier ?? "") == wanted
            }
            return supported ? .available : .unsupportedLanguage(language)
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceDisabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .modelNotReady
            }
        @unknown default:
            return .modelNotReady
        }
    }
    #endif

    // MARK: - 해설 만들기

    @discardableResult
    public func explain(
        quote: Quote,
        author: Author,
        language: AppLanguage,
        onUpdate: @escaping @MainActor (QuoteExplanation) -> Void
    ) async throws -> QuoteExplanation {
        let availability = availability(for: language)
        guard availability.canExplain else {
            throw QuoteExplainerError.unavailable(availability)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await stream(quote: quote, author: author, language: language, onUpdate: onUpdate)
        }
        #endif
        throw QuoteExplainerError.unavailable(.requiresNewerOS)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func stream(
        quote: Quote,
        author: Author,
        language: AppLanguage,
        onUpdate: @escaping @MainActor (QuoteExplanation) -> Void
    ) async throws -> QuoteExplanation {
        let session = session(for: language)
        let prompt = QuoteExplainerPrompt.prompt(quote: quote, author: author, language: language)

        var latest = QuoteExplanation(summary: "", context: "", practice: "")
        do {
            // 스키마를 프롬프트에 또 넣지 않는다. 모델이 형식을 이미 알고 있어
            // 문맥(4096 토큰)을 아낄 수 있다.
            let stream = session.streamResponse(
                to: prompt,
                generating: GeneratedExplanation.self,
                includeSchemaInPrompt: false
            )
            for try await partial in stream {
                latest = QuoteExplanation(
                    summary: partial.summary ?? "",
                    context: partial.context ?? "",
                    practice: partial.practice ?? ""
                )
                onUpdate(latest)
            }
        } catch {
            throw QuoteExplainerError.generationFailed(error.localizedDescription)
        }

        guard latest.isComplete else {
            throw QuoteExplainerError.generationFailed("incomplete")
        }
        return latest
    }

    @available(iOS 26.0, *)
    private func session(for language: AppLanguage) -> LanguageModelSession {
        if let existing = sessions[language] as? LanguageModelSession {
            return existing
        }
        let created = LanguageModelSession(
            instructions: QuoteExplainerPrompt.instructions(language: language)
        )
        sessions[language] = created
        return created
    }
    #endif
}

#if canImport(FoundationModels)
/// 모델이 채워 줄 세 칸.
///
/// `@Generable` 은 이 형식에서 `PartiallyGenerated` (모든 칸이 옵셔널)를 만들어
/// 주고, 스트리밍 중에는 칸이 하나씩 채워진다. 그래서 화면이 글자를 받는 대로
/// 그릴 수 있다.
@available(iOS 26.0, *)
@Generable
struct GeneratedExplanation {
    @Guide(description: "What the quote means, in two plain sentences.")
    var summary: String

    @Guide(description: "The situation or life of the author behind the quote, in two sentences. Do not invent facts.")
    var context: String

    @Guide(description: "One small, concrete thing the reader can do today.")
    var practice: String
}
#endif
