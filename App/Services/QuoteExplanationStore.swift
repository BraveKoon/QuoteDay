import Foundation
import Observation

/// 화면이 해설을 요청하고 결과를 받는 곳.
///
/// 뷰가 기기 모델을 직접 만지지 않는 이유:
/// - 생성 중 상태(부분 결과)와 저장된 결과를 **한곳에서** 관리해야 화면이 흔들리지 않는다.
/// - 같은 명언을 두 화면이 동시에 열어도 생성은 한 번만 돌아야 한다(배터리).
/// - 테스트에서 가짜 해설자를 끼워 넣을 수 있어야 한다.
@MainActor
@Observable
public final class QuoteExplanationStore {

    /// 명언 하나의 지금 상태.
    public enum Phase: Equatable {
        /// 아직 만들지 않았다. (버튼을 보여 준다)
        case idle
        /// 지금 만들고 있다. 부분 결과를 들고 있다.
        case generating(QuoteExplanation)
        /// 완성된 해설이 있다.
        case ready(QuoteExplanation)
        /// 실패했다. 문장을 들고 있다.
        case failed(String)
    }

    private let cache: QuoteExplanationCache
    private let explainer: QuoteExplaining

    /// 명언·언어별 상태. 생성 중이거나 방금 만든 것만 담긴다.
    private var phases: [String: Phase] = [:]
    /// 파일에서 읽은 해설. 처음 한 번만 읽는다.
    private var stored: [String: QuoteExplanation] = [:]
    private var didLoadCache = false
    /// 진행 중인 생성 작업. 같은 명언을 두 번 만들지 않는다.
    private var running: [String: Task<Void, Never>] = [:]

    public init(
        explainer: QuoteExplaining? = nil,
        cache: QuoteExplanationCache = .standard()
    ) {
        self.explainer = explainer ?? FoundationModelsQuoteExplainer()
        self.cache = cache
        // 파일 읽기는 여기서 끝낸다. 화면을 그리는 도중에 파일을 읽으면
        // 뷰 업데이트 중 상태가 바뀌어 경고가 나고, 스크롤이 끊긴다.
        self.stored = cache.load()
        self.didLoadCache = true
    }

    // MARK: - 쓸 수 있는지

    public func availability(for language: AppLanguage) -> QuoteExplainerAvailability {
        explainer.availability(for: language)
    }

    /// 이 명언·언어의 캐시 키.
    public func key(for quote: Quote, language: AppLanguage) -> String {
        QuoteExplainerPrompt.cacheKey(slug: quote.slug, language: language)
    }

    // MARK: - 상태

    public func phase(for quote: Quote, language: AppLanguage) -> Phase {
        let key = key(for: quote, language: language)
        if let phase = phases[key] { return phase }
        if let saved = savedExplanation(forKey: key) { return .ready(saved) }
        return .idle
    }

    /// 저장된 해설. 없으면 nil.
    public func savedExplanation(forKey key: String) -> QuoteExplanation? {
        loadCacheIfNeeded()
        return stored[key]
    }

    /// 이 언어로 저장된 편수. 설정 화면에서 쓴다.
    public func savedCount(for language: AppLanguage? = nil) -> Int {
        loadCacheIfNeeded()
        guard let language else { return stored.count }
        let marker = "|\(language.rawValue)|"
        return stored.keys.filter { $0.contains(marker) }.count
    }

    // MARK: - 만들기

    /// 해설을 만든다. 이미 있으면 아무 일도 하지 않는다(`force: true` 면 다시 만든다).
    public func explain(
        quote: Quote,
        author: Author,
        language: AppLanguage,
        force: Bool = false
    ) {
        let key = key(for: quote, language: language)
        if running[key] != nil { return }
        if !force, let saved = savedExplanation(forKey: key) {
            phases[key] = .ready(saved)
            return
        }

        let availability = explainer.availability(for: language)
        guard availability.canExplain else {
            phases[key] = .failed(availability.explanation ?? L("지금은 해설을 만들 수 없어요."))
            return
        }

        phases[key] = .generating(QuoteExplanation(summary: "", context: "", practice: ""))
        running[key] = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.explainer.explain(
                    quote: quote,
                    author: author,
                    language: language
                ) { [weak self] partial in
                    // 부분 결과는 비어 있는 칸이 있어도 그대로 그린다.
                    // 글자가 차례로 나타나야 기다리는 느낌이 줄어든다.
                    self?.phases[key] = .generating(partial)
                }
                self.phases[key] = .ready(result)
                self.stored[key] = result
                self.cache.save(result, forKey: key)
            } catch is CancellationError {
                self.phases[key] = .idle
            } catch let error as QuoteExplainerError {
                self.phases[key] = .failed(error.errorDescription ?? L("해설을 만들지 못했어요."))
            } catch {
                self.phases[key] = .failed(L("해설을 만들지 못했어요. 잠시 뒤 다시 시도해 주세요."))
            }
            self.running[key] = nil
        }
    }

    /// 만들기를 그만둔다. 부분 결과는 버린다.
    public func cancel(quote: Quote, language: AppLanguage) {
        let key = key(for: quote, language: language)
        running[key]?.cancel()
        running[key] = nil
        if case .generating = phases[key] {
            phases[key] = .idle
        }
    }

    /// "다시 생성" — 저장된 해설을 지우고 새로 만든다.
    public func regenerate(quote: Quote, author: Author, language: AppLanguage) {
        let key = key(for: quote, language: language)
        stored[key] = nil
        phases[key] = nil
        cache.remove(forKey: key)
        explain(quote: quote, author: author, language: language, force: true)
    }

    /// 저장된 해설을 모두 지운다. (설정 → 저장 공간)
    public func clearSaved() {
        for task in running.values { task.cancel() }
        running.removeAll()
        phases.removeAll()
        stored.removeAll()
        didLoadCache = true
        cache.clear()
    }

    // MARK: - 내부

    private func loadCacheIfNeeded() {
        guard !didLoadCache else { return }
        didLoadCache = true
        stored = cache.load()
    }
}
