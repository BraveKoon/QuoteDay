import Foundation

/// ZenQuotes `/today` 에서 받아 온 오늘의 명언.
///
/// API 는 영어 문장과 저자 이름만 준다. 카테고리와 인물 소개는 없으므로
/// 저자 이름이 내장 인물 데이터와 일치하면 그 소개를 붙여 주고,
/// 아니면 이름만 있는 최소한의 인물 정보를 만든다.
public struct RemoteQuote: Codable, Hashable, Sendable {
    public let text: String
    public let authorName: String
    /// 이 명언이 "오늘"인 날짜 키(yyyy-MM-dd). 날짜가 바뀌면 캐시를 무효로 본다.
    public let dayKey: String
    public let fetchedAt: Date

    public init(text: String, authorName: String, dayKey: String, fetchedAt: Date = .now) {
        self.text = text
        self.authorName = authorName
        self.dayKey = dayKey
        self.fetchedAt = fetchedAt
    }

    /// 내장 명언과 구분하기 위한 slug 접두사.
    public static let slugPrefix = "zen-"

    /// 같은 문장이면 항상 같은 slug → 같은 UUID.
    /// 딥링크(알림·위젯 탭)가 날짜와 무관하게 유효하도록 내용에서 유도한다.
    public var slug: String {
        let seed = "\(authorName)|\(text)"
        return Self.slugPrefix + String(StableHash.fnv1a(seed), radix: 16)
    }

    public func quote() -> Quote {
        Quote(
            slug: slug,
            text: text,
            authorID: resolvedAuthor.id,
            // API 가 카테고리를 주지 않으므로 중립적인 '일상'으로 둔다.
            category: .daily
        )
    }

    /// 저자 이름이 내장 인물과 겹치면 소개·생몰년까지 함께 보여 줄 수 있다.
    public var resolvedAuthor: Author {
        if let known = AuthorLibrary.author(matchingName: authorName) {
            return known
        }
        return Author(
            id: "remote:\(authorName.lowercased())",
            name: authorName,
            birthYear: nil,
            occupation: "명언 저자",
            nationality: "미상",
            biography: "이 인물의 상세 소개는 아직 앱에 준비되어 있지 않습니다. ZenQuotes 에서 받아 온 오늘의 명언입니다.",
            achievements: []
        )
    }

    public func presentation() -> QuotePresentation {
        QuotePresentation(quote: quote(), author: resolvedAuthor)
    }
}

public extension Quote {
    /// ZenQuotes 에서 받아 온 명언인지.
    var isFromZenQuotes: Bool { slug.hasPrefix(RemoteQuote.slugPrefix) }
}

/// ZenQuotes `/today` 호출과 캐시.
///
/// 네트워크가 없거나 실패해도 아무것도 던지지 않는다. 호출부는 캐시가
/// 비어 있으면 내장 명언으로 자연스럽게 되돌아간다.
public struct RemoteQuoteStore: @unchecked Sendable {
    public static let shared = RemoteQuoteStore()

    /// ZenQuotes 무료 등급은 30초에 5회로 제한된다.
    /// 실패했을 때 이 간격 안에서는 다시 시도하지 않는다.
    public static let retryInterval: TimeInterval = 15 * 60
    public static let endpoint = URL(string: "https://zenquotes.io/api/today")!
    /// 무료 등급 이용 조건에 따라 화면에 표시해야 하는 출처 문구.
    public static let attribution = "Inspirational quotes provided by ZenQuotes API"
    public static let attributionURL = URL(string: "https://zenquotes.io/")!

    private let defaults: UserDefaults
    private let calendar: Calendar

    public init(defaults: UserDefaults = AppGroup.defaults, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    // MARK: - 캐시 읽기

    public func cached() -> RemoteQuote? {
        guard let data = defaults.data(forKey: SharedDefaultsKey.remoteQuote) else { return nil }
        return try? JSONDecoder.quoteDay.decode(RemoteQuote.self, from: data)
    }

    /// 해당 날짜의 명언이 캐시에 있을 때만 돌려준다.
    /// 어제 것을 오늘 보여 주지 않기 위해 날짜 키를 확인한다.
    public func presentation(on date: Date = .now) -> QuotePresentation? {
        guard let cached = cached(), cached.dayKey == date.dayKey(calendar: calendar) else {
            return nil
        }
        return cached.presentation()
    }

    /// 딥링크로 들어온 UUID 가 캐시된 원격 명언인지 확인한다.
    /// (날짜가 지나도 알림·위젯 링크가 살아 있도록 날짜는 보지 않는다.)
    public func presentation(matching id: UUID) -> QuotePresentation? {
        guard let cached = cached() else { return nil }
        let presentation = cached.presentation()
        return presentation.quote.id == id ? presentation : nil
    }

    public var lastAttemptDate: Date? {
        defaults.object(forKey: SharedDefaultsKey.remoteQuoteLastAttempt) as? Date
    }

    public var lastErrorMessage: String? {
        defaults.string(forKey: SharedDefaultsKey.remoteQuoteLastError)
    }

    /// 사용자가 이 기능을 켜 두었는지. 위젯도 같은 값을 읽는다.
    public var isEnabled: Bool {
        defaults.object(forKey: SharedDefaultsKey.remoteQuoteEnabled) as? Bool ?? true
    }

    // MARK: - 갱신

    /// 오늘 것이 이미 있으면 아무것도 하지 않는다.
    /// - Returns: 캐시가 실제로 갱신되었으면 `true`.
    @discardableResult
    public func refreshIfNeeded(now: Date = .now, session: URLSession = .shared) async -> Bool {
        guard isEnabled else { return false }
        if let cached = cached(), cached.dayKey == now.dayKey(calendar: calendar) {
            return false
        }
        // 오프라인 상태에서 매번 두드리지 않도록 재시도 간격을 둔다.
        if let lastAttempt = lastAttemptDate,
           now.timeIntervalSince(lastAttempt) < Self.retryInterval {
            return false
        }
        return await refresh(now: now, session: session)
    }

    /// 사용자가 직접 "지금 새로고침"을 눌렀을 때. 재시도 간격을 무시한다.
    @discardableResult
    public func refresh(now: Date = .now, session: URLSession = .shared) async -> Bool {
        defaults.set(now, forKey: SharedDefaultsKey.remoteQuoteLastAttempt)

        var request = URLRequest(url: Self.endpoint)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw RemoteQuoteError.badStatus(http.statusCode)
            }
            let quote = try Self.parse(data, dayKey: now.dayKey(calendar: calendar), fetchedAt: now)
            save(quote)
            defaults.removeObject(forKey: SharedDefaultsKey.remoteQuoteLastError)
            AppLog.quotes.debug("ZenQuotes 갱신 성공")
            return true
        } catch {
            defaults.set(error.localizedDescription, forKey: SharedDefaultsKey.remoteQuoteLastError)
            AppLog.quotes.error("ZenQuotes 갱신 실패: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func save(_ quote: RemoteQuote) {
        guard let data = try? JSONEncoder.quoteDay.encode(quote) else { return }
        defaults.set(data, forKey: SharedDefaultsKey.remoteQuote)
    }

    public func clear() {
        defaults.removeObject(forKey: SharedDefaultsKey.remoteQuote)
        defaults.removeObject(forKey: SharedDefaultsKey.remoteQuoteLastError)
        defaults.removeObject(forKey: SharedDefaultsKey.remoteQuoteLastAttempt)
    }

    // MARK: - 파싱

    /// 응답 본문 형태: `[{"q":"...","a":"...","h":"..."}]`
    private struct ZenQuoteDTO: Decodable {
        let q: String
        let a: String
    }

    /// 네트워크와 분리해 두어 테스트할 수 있게 한다.
    public static func parse(_ data: Data, dayKey: String, fetchedAt: Date = .now) throws -> RemoteQuote {
        let items = try JSONDecoder().decode([ZenQuoteDTO].self, from: data)
        guard let first = items.first else { throw RemoteQuoteError.emptyResponse }

        let text = first.q.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = first.a.trimmingCharacters(in: .whitespacesAndNewlines)

        // 사용량을 초과하면 ZenQuotes 는 200 과 함께 안내 문구를 본문에 담아 보낸다.
        // 이걸 명언으로 저장하면 "Too many requests" 가 위젯에 뜬다.
        guard author.lowercased() != "zenquotes.io" else { throw RemoteQuoteError.rateLimited }
        guard !text.isEmpty, !author.isEmpty else { throw RemoteQuoteError.emptyResponse }

        return RemoteQuote(text: text, authorName: author, dayKey: dayKey, fetchedAt: fetchedAt)
    }
}

public enum RemoteQuoteError: LocalizedError, Equatable {
    case emptyResponse
    case rateLimited
    case badStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyResponse: "명언을 받아 오지 못했습니다."
        case .rateLimited: "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요."
        case .badStatus(let code): "서버 응답 오류 (\(code))"
        }
    }
}
