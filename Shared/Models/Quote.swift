import Foundation

/// 명언 한 편.
///
/// 원본 요구사항의 `Quote` 구조체를 확장했다. 차이점과 이유:
/// - `author` 를 문자열이 아닌 `authorID` 참조로 바꿔 인물 정보를 한 곳에서 관리한다.
/// - `id` 는 랜덤 UUID 가 아니라 `slug` 로부터 **결정적으로** 생성한다.
///   알림 payload 와 위젯 딥링크가 앱 재실행 후에도 같은 명언을 가리켜야 하기 때문이다.
/// - 하나의 명언이 여러 상황에 어울릴 수 있어 `secondaryCategories` 를 추가했다.
public struct Quote: Identifiable, Hashable, Codable, Sendable {
    /// 사람이 읽을 수 있는 고유 키. 데이터 파일에서 중복되면 안 된다.
    public let slug: String
    /// 한국어 문장.
    public let text: String
    /// 확인된 원문(있을 때만). 상세 화면에서 함께 보여 준다.
    public let originalText: String?
    public let authorID: String
    public let category: AppCategory
    public let secondaryCategories: [AppCategory]

    public init(
        slug: String,
        text: String,
        originalText: String? = nil,
        authorID: String,
        category: AppCategory,
        secondaryCategories: [AppCategory] = []
    ) {
        self.slug = slug
        self.text = text
        self.originalText = originalText
        self.authorID = authorID
        self.category = category
        self.secondaryCategories = secondaryCategories
    }

    /// slug 기반의 안정적 UUID.
    public var id: UUID { UUID(stableSeed: "quote:\(slug)") }

    /// 이 명언이 속한 모든 카테고리.
    public var categories: [AppCategory] { [category] + secondaryCategories }

    public func matches(_ category: AppCategory) -> Bool {
        categories.contains(category)
    }

    /// 번역된 사본.
    ///
    /// 한국어 원문은 언제나 `text` 에 남아 있고(사전 키가 slug 라 문장이 바뀌어도
    /// 키는 그대로다), 화면에 보이는 문장만 언어에 따라 바뀐다.
    /// 사전에 번역이 없으면 **한국어 원문을 그대로** 돌려준다.
    public func localized(in language: AppLanguage = Localization.language) -> Quote {
        guard language.usesTranslationTable else { return self }

        let key = "quote.\(slug).text"
        guard Localization.hasTranslation(key, language: language) else { return self }

        let translated = Localization.string(key, language: language)
        // 영어에서는 원문과 번역문이 같은 경우가 많다. 같은 문장을 두 번 쓰지 않는다.
        let original = translated.compare(originalText ?? "", options: .caseInsensitive) == .orderedSame
            ? nil
            : originalText

        return Quote(
            slug: slug,
            text: translated,
            originalText: original,
            authorID: authorID,
            category: category,
            secondaryCategories: secondaryCategories
        )
    }
}

/// 명언 + 인물을 한 번에 넘기기 위한 표시용 묶음.
public struct QuotePresentation: Identifiable, Hashable, Sendable {
    public let quote: Quote
    public let author: Author

    public init(quote: Quote, author: Author) {
        self.quote = quote
        self.author = author
    }

    public var id: UUID { quote.id }

    /// 공유 시트나 알림 본문에 쓰는 한 줄 표현.
    public var shareText: String {
        "\u{201C}\(quote.text)\u{201D}\n— \(author.displayName)"
    }
}
