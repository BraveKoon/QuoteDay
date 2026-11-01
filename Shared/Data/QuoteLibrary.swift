import Foundation

/// 명언 데이터에 대한 읽기 전용 색인.
///
/// 앱과 위젯이 같은 인스턴스를 쓰며, 모든 조회는 미리 만들어 둔 딕셔너리를 통해
/// O(1) 로 이루어진다.
///
/// 언어별 사본도 **처음에 한 번만** 만든다. 화면을 그릴 때마다 201편을
/// 번역 사전에서 다시 찾으면 목록 하나에 수백 번의 조회가 쌓이기 때문이다.
/// 사본은 문장만 바뀌고 `slug`·`id`·카테고리는 원본과 같아서 딥링크와
/// 하트·기록이 언어와 무관하게 이어진다.
public struct QuoteLibrary: Sendable {
    /// 한국어 원본. 번역 사전의 키가 여기서 나온다.
    public let sourceQuotes: [Quote]
    /// 언어별 표시용 사본.
    private let variants: [AppLanguage: [Quote]]
    private let ids: [AppLanguage: [UUID: Quote]]
    private let slugs: [AppLanguage: [String: Quote]]
    private let buckets: [AppLanguage: [AppCategory: [Quote]]]

    public static let shared = QuoteLibrary(quotes: QuoteSeed.all)

    public init(quotes: [Quote]) {
        self.sourceQuotes = quotes

        var variants: [AppLanguage: [Quote]] = [:]
        var ids: [AppLanguage: [UUID: Quote]] = [:]
        var slugs: [AppLanguage: [String: Quote]] = [:]
        var buckets: [AppLanguage: [AppCategory: [Quote]]] = [:]

        for language in AppLanguage.allCases {
            let localized = quotes.map { $0.localized(in: language) }
            variants[language] = localized
            ids[language] = Dictionary(
                localized.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            slugs[language] = Dictionary(
                localized.map { ($0.slug, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var categoryBuckets: [AppCategory: [Quote]] = [:]
            for quote in localized {
                for category in quote.categories {
                    categoryBuckets[category, default: []].append(quote)
                }
            }
            buckets[language] = categoryBuckets
        }

        self.variants = variants
        self.ids = ids
        self.slugs = slugs
        self.buckets = buckets

        assert(
            Set(quotes.map(\.slug)).count == quotes.count,
            "Quote slug 가 중복되었습니다. 딥링크가 어긋날 수 있습니다."
        )
        assert(
            quotes.allSatisfy { AuthorLibrary.byID[$0.authorID] != nil },
            "AuthorLibrary 에 없는 authorID 를 참조하는 명언이 있습니다."
        )
    }

    /// 지금 언어로 옮긴 전체 명언.
    public var quotes: [Quote] { variants[Localization.language] ?? sourceQuotes }

    public var count: Int { sourceQuotes.count }

    public func quote(id: UUID) -> Quote? {
        (ids[Localization.language] ?? [:])[id]
    }

    public func quote(slug: String) -> Quote? {
        (slugs[Localization.language] ?? [:])[slug]
    }

    /// 해당 카테고리에 직접 속하거나 보조 카테고리로 지정된 명언.
    public func quotes(in category: AppCategory) -> [Quote] {
        (buckets[Localization.language] ?? [:])[category] ?? []
    }

    public func count(in category: AppCategory) -> Int {
        (buckets[Localization.language] ?? [:])[category]?.count ?? 0
    }

    public func author(for quote: Quote) -> Author {
        AuthorLibrary.author(id: quote.authorID)
    }

    public func presentation(for quote: Quote) -> QuotePresentation {
        QuotePresentation(quote: quote, author: author(for: quote))
    }

    public func presentation(id: UUID) -> QuotePresentation? {
        quote(id: id).map(presentation(for:))
    }

    /// 한 인물이 남긴 모든 명언.
    public func quotes(byAuthor authorID: String) -> [Quote] {
        quotes.filter { $0.authorID == authorID }
    }

    /// 텍스트/인물 이름 검색. 비어 있는 질의는 전체를 돌려준다.
    ///
    /// 지금 언어로 옮긴 문장은 물론 **한국어 원문과 영어 원문**까지 함께 본다.
    /// 영어로 보는 중에 "처칠"로 찾아도 결과가 나와야 하기 때문이다.
    public func search(_ term: String) -> [Quote] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return quotes }

        let originals = Dictionary(
            sourceQuotes.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return quotes.filter { quote in
            let author = AuthorLibrary.author(id: quote.authorID)
            if quote.text.localizedCaseInsensitiveContains(trimmed)
                || author.name.localizedCaseInsensitiveContains(trimmed)
                || (author.koreanName?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (quote.originalText?.localizedCaseInsensitiveContains(trimmed) ?? false) {
                return true
            }
            guard let original = originals[quote.slug] else { return false }
            if original.text.localizedCaseInsensitiveContains(trimmed)
                || (original.originalText?.localizedCaseInsensitiveContains(trimmed) ?? false) {
                return true
            }
            // 언어를 바꿔도 검색은 모든 언어를 훑는다. 영어로 보는 중에
            // 기억나는 한국어 문장 일부로도 찾을 수 있어야 한다.
            return AppLanguage.allCases.contains { language in
                original.localized(in: language).text.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }

    /// 데이터가 비어 있어도 UI 가 무언가는 보여 줄 수 있도록 하는 최종 폴백.
    public static let placeholder = Quote(
        slug: "placeholder",
        text: "오늘 하루도 당신의 속도로 충분합니다.",
        authorID: "unknown",
        category: .daily
    )
}
