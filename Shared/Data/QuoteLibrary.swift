import Foundation

/// 명언 데이터에 대한 읽기 전용 색인.
///
/// 앱과 위젯이 같은 인스턴스를 쓰며, 모든 조회는 미리 만들어 둔 딕셔너리를 통해
/// O(1) 로 이루어진다.
public struct QuoteLibrary: Sendable {
    public let quotes: [Quote]
    private let byID: [UUID: Quote]
    private let bySlug: [String: Quote]
    private let byCategory: [AppCategory: [Quote]]

    public static let shared = QuoteLibrary(quotes: QuoteSeed.all)

    public init(quotes: [Quote]) {
        self.quotes = quotes
        self.byID = Dictionary(quotes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.bySlug = Dictionary(quotes.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })

        var buckets: [AppCategory: [Quote]] = [:]
        for quote in quotes {
            for category in quote.categories {
                buckets[category, default: []].append(quote)
            }
        }
        self.byCategory = buckets

        assert(bySlug.count == quotes.count, "Quote slug 가 중복되었습니다. 딥링크가 어긋날 수 있습니다.")
        assert(
            quotes.allSatisfy { AuthorLibrary.byID[$0.authorID] != nil },
            "AuthorLibrary 에 없는 authorID 를 참조하는 명언이 있습니다."
        )
    }

    public var count: Int { quotes.count }

    public func quote(id: UUID) -> Quote? { byID[id] }

    public func quote(slug: String) -> Quote? { bySlug[slug] }

    /// 해당 카테고리에 직접 속하거나 보조 카테고리로 지정된 명언.
    public func quotes(in category: AppCategory) -> [Quote] {
        byCategory[category] ?? []
    }

    public func count(in category: AppCategory) -> Int {
        byCategory[category]?.count ?? 0
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
    public func search(_ term: String) -> [Quote] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return quotes }
        return quotes.filter { quote in
            let author = AuthorLibrary.author(id: quote.authorID)
            return quote.text.localizedCaseInsensitiveContains(trimmed)
                || author.name.localizedCaseInsensitiveContains(trimmed)
                || (author.koreanName?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (quote.originalText?.localizedCaseInsensitiveContains(trimmed) ?? false)
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
