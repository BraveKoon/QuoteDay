import Foundation

/// 명언 선택 규칙을 담당한다.
///
/// 모든 선택은 **결정적**이다. 같은 (날짜, 카테고리, seed) 조합이면 앱을 다시 켜도,
/// 위젯 프로세스에서 계산해도 같은 결과가 나온다. 랜덤을 쓰지 않는 이유는
/// 홈 화면 위젯과 앱 본체가 서로 다른 프로세스에서 같은 "오늘의 명언"을
/// 보여 주어야 하기 때문이다.
public struct QuoteService: Sendable {
    private let library: QuoteLibrary
    private let calendar: Calendar

    public static let shared = QuoteService()

    public init(library: QuoteLibrary = .shared, calendar: Calendar = .current) {
        self.library = library
        self.calendar = calendar
    }

    // MARK: - 오늘의 명언

    /// 날짜 → 해시 → 인덱스. 자정이 지나면 자동으로 다음 명언으로 넘어간다.
    public func quoteOfTheDay(for date: Date = .now) -> Quote {
        let pool = library.quotes
        guard !pool.isEmpty else { return QuoteLibrary.placeholder }
        let index = StableHash.index(for: "daily:\(date.dayKey(calendar: calendar))", count: pool.count)
        return pool[index]
    }

    /// 사용자가 설정에서 선호 카테고리를 골랐을 때의 오늘의 명언.
    public func quoteOfTheDay(for date: Date = .now, preferred category: AppCategory?) -> Quote {
        guard let category else { return quoteOfTheDay(for: date) }
        let pool = library.quotes(in: category)
        guard !pool.isEmpty else { return quoteOfTheDay(for: date) }
        let index = StableHash.index(
            for: "daily:\(category.rawValue):\(date.dayKey(calendar: calendar))",
            count: pool.count
        )
        return pool[index]
    }

    public func presentationOfTheDay(for date: Date = .now, preferred category: AppCategory? = nil) -> QuotePresentation {
        library.presentation(for: quoteOfTheDay(for: date, preferred: category))
    }

    // MARK: - 카테고리 기반 선택

    /// 카테고리에 어울리는 명언을 고른다.
    ///
    /// 1. 해당 카테고리의 명언
    /// 2. 부족하면 `AppCategory.related` 순서로 확장
    /// 3. 그래도 없으면 전체 풀
    ///
    /// - Parameter seed: 같은 일정에 대해 항상 같은 명언이 나오도록 하는 키.
    ///   일정 ID + 시작 시각을 넣으면 일정을 수정하기 전까지 명언이 고정된다.
    public func quote(for category: AppCategory, seed: String) -> Quote {
        let pool = candidatePool(for: category)
        guard !pool.isEmpty else { return QuoteLibrary.placeholder }
        let index = StableHash.index(for: "cat:\(category.rawValue):\(seed)", count: pool.count)
        return pool[index]
    }

    /// 폴백까지 적용한 후보 목록. 테스트에서 직접 검증한다.
    public func candidatePool(for category: AppCategory) -> [Quote] {
        var seen = Set<String>()
        var pool: [Quote] = []

        func append(_ quotes: [Quote]) {
            for quote in quotes where !seen.contains(quote.slug) {
                seen.insert(quote.slug)
                pool.append(quote)
            }
        }

        append(library.quotes(in: category))
        // 후보가 너무 적으면 매번 같은 명언만 보이므로 관련 카테고리로 넓힌다.
        if pool.count < Self.minimumPoolSize {
            for related in category.related {
                append(library.quotes(in: related))
                if pool.count >= Self.minimumPoolSize { break }
            }
        }
        if pool.isEmpty {
            append(library.quotes)
        }
        return pool
    }

    /// 이 값보다 후보가 적으면 관련 카테고리를 끌어온다.
    public static let minimumPoolSize = 6

    // MARK: - 일정 연결

    /// 일정에 붙일 명언. 일정의 식별자와 시작 시각을 seed 로 삼는다.
    public func quote(forScheduleID id: UUID, start: Date, category: AppCategory) -> Quote {
        quote(for: category, seed: "\(id.uuidString):\(Int(start.timeIntervalSince1970))")
    }

    // MARK: - 조회

    public func quote(id: UUID) -> Quote? { library.quote(id: id) }
    public func quote(slug: String) -> Quote? { library.quote(slug: slug) }
    public func author(for quote: Quote) -> Author { library.author(for: quote) }
    public func presentation(for quote: Quote) -> QuotePresentation { library.presentation(for: quote) }
    /// 딥링크로 들어온 명언 조회.
    ///
    /// 내장 라이브러리에 없으면 ZenQuotes 캐시까지 확인한다. 알림이나 위젯이
    /// 원격 명언을 가리키고 있을 수 있기 때문이다.
    public func presentation(id: UUID, remote: RemoteQuoteStore = .shared) -> QuotePresentation? {
        library.presentation(id: id) ?? remote.presentation(matching: id)
    }

    /// 오늘의 명언. 원격 사용이 켜져 있고 오늘 자 캐시가 있으면 그것을 쓴다.
    ///
    /// 캐시가 없거나(첫 실행·오프라인) 기능이 꺼져 있으면 내장 명언으로 되돌아가므로
    /// 네트워크 없이도 화면은 항상 채워진다.
    public func todayPresentation(
        for date: Date = .now,
        preferred category: AppCategory? = nil,
        useRemote: Bool,
        remote: RemoteQuoteStore = .shared
    ) -> QuotePresentation {
        if useRemote, let remotePresentation = remote.presentation(on: date) {
            return remotePresentation
        }
        return presentationOfTheDay(for: date, preferred: category)
    }
    public func quotes(in category: AppCategory) -> [Quote] { library.quotes(in: category) }
    public func quotes(byAuthor authorID: String) -> [Quote] { library.quotes(byAuthor: authorID) }
    public func search(_ term: String) -> [Quote] { library.search(term) }
    public var allQuotes: [Quote] { library.quotes }
    public var quoteCount: Int { library.count }
}
