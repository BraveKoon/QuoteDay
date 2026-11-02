import Foundation

/// AI 대화를 누구에게 물어볼지.
///
/// 두 갈래를 둔 이유:
/// - **온디바이스**: 기기 안에서 끝난다. 키도, 요금도, 네트워크도 필요 없다.
///   대신 기기·OS 를 가리고 답이 짧다.
/// - **Qwen(DashScope)**: 훨씬 똑똑하고 길게 답한다. 대신 **사용자 자기 키**가
///   필요하고, 질문이 알리바바 클라우드로 나간다.
///
/// 앱에 키를 넣어 배포하지 않는다. 배포된 앱의 키는 결국 모두에게 공개되고,
/// 남의 요금으로 도는 통로가 된다. 그래서 열쇠는 사용자가 직접 넣는다.
public enum AIChatProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case onDevice
    case qwen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onDevice: L("온디바이스 (무료)")
        case .qwen: L("Qwen (내 API 키)")
        }
    }

    public var detail: String {
        switch self {
        case .onDevice:
            L("기기 안에서 답해요. 인터넷도, 키도, 요금도 필요 없어요.")
        case .qwen:
            L("알리바바 클라우드의 Qwen 이 답해요. 질문이 그쪽으로 전송되고, 내 API 키로 요금이 나가요.")
        }
    }

    public var symbol: String {
        switch self {
        case .onDevice: "iphone.gen3"
        case .qwen: "cloud"
        }
    }

    /// 이 통로를 쓰려면 API 키가 필요한지.
    public var requiresKey: Bool { self == .qwen }

    /// 질문이 기기 밖으로 나가는지. 화면에 그대로 적는다.
    public var leavesDevice: Bool { self == .qwen }
}

/// Qwen 이 있는 지역. 계정을 만든 곳과 가까운 쪽을 쓴다.
public enum QwenRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case international
    case china

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .international: L("국제 (싱가포르)")
        case .china: L("중국 (베이징)")
        }
    }

    /// OpenAI 호환 엔드포인트. 앱은 `/chat/completions` 만 부른다.
    public var baseURL: String {
        switch self {
        case .international: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        case .china: "https://dashscope.aliyuncs.com/compatible-mode/v1"
        }
    }

    public var chatURL: URL? { URL(string: baseURL + "/chat/completions") }
}

/// 대화에 실어 보내는 명언 맥락.
///
/// 사용자가 "이 명언"이라고 말할 때 무엇을 가리키는지 모델이 알아야 한다.
/// 화면에서 보고 있는 명언 한 편을 통째로 넣는다 — 본문·원문·인물·직업·국적·
/// 시대, 그리고 큐레이션된 비하인드 스토리가 있으면 그것까지.
public struct QuoteChatContext: Hashable, Sendable {
    public let quote: Quote
    public let author: Author
    /// 앱에 준비된 배경 이야기(있을 때만). 사람이 쓴 글이므로 모델이 지어낸
    /// 것보다 정확하다. 프롬프트에서 "확인된 자료"로 표시한다.
    public let story: BehindStory?

    public init(quote: Quote, author: Author, story: BehindStory? = nil) {
        self.quote = quote
        self.author = author
        self.story = story
    }

    /// 오늘의 명언.
    public static func today(
        service: QuoteService = .shared,
        now: Date = .now
    ) -> QuoteChatContext {
        let presentation = service.presentationOfTheDay(for: now)
        return QuoteChatContext(
            quote: presentation.quote,
            author: presentation.author,
            story: BehindStoryLibrary.story(for: presentation.quote.slug)
        )
    }
}

/// 대화 시스템 프롬프트.
///
/// 화면이 아니라 여기에 두는 이유는 **테스트할 수 있게** 하기 위해서다.
/// 클라우드 모델은 CI 에서 부를 수 없지만, 프롬프트에 무엇이 들어가는지는
/// 문자열 비교로 확인할 수 있다.
public enum QuoteChatPrompt {

    /// 캐시·표시용 판 번호. 프롬프트를 고치면 올린다.
    public static let version = 1

    public static func languageName(_ language: AppLanguage) -> String {
        QuoteExplainerPrompt.languageName(language)
    }

    /// 모델의 역할. "무엇을 하는 사람인지"와 "무엇을 하지 말아야 하는지"를 정한다.
    public static func instructions(language: AppLanguage) -> String {
        """
        너는 QuoteDay 앱 안의 명언 안내자다. 사용자가 명언의 **숨은 뜻**, 이해가 안 되는
        구절, **작가의 일생과 시대**, 지금 자기 상황에 어떻게 적용할지를 묻는다.

        규칙:
        1. 답은 반드시 \(languageName(language)) 로 쓴다.
        2. 먼저 한 문장으로 핵심을 말하고, 그 뒤에 이유를 붙인다. 3~6문장.
        3. 확인되지 않은 일화·연도·명언을 지어내지 않는다. 확실하지 않으면
           "확실히 전해지는 기록은 없지만" 처럼 밝히고 해석으로 말한다.
        4. 작가의 일생을 말할 때는 생몰년·국적·직업처럼 앱에 있는 사실을 우선한다.
        5. 사용자의 감정을 함부로 단정하지 않는다. 설교조("~해야 합니다")를 쓰지 않는다.
        6. 앱에 없는 명언을 물으면, 아는 범위에서 답하되 앱에 수록된 문장이 아니라고 알린다.
        7. 목록 기호·제목·인사말을 남발하지 않는다. 대화하듯 담담하게 쓴다.
        """
    }

    /// 이번 질문에 함께 보낼 맥락. 없으면 앱 소개만 붙는다.
    public static func contextBlock(_ context: QuoteChatContext?, language: AppLanguage) -> String {
        guard let context else {
            return """
            [앱 정보] QuoteDay 는 명언 201편과 인물 116명을 담은 앱이다.
            특정 명언이 정해지지 않았다. 사용자가 문장을 말하면 그 문장으로 답한다.
            """
        }

        var lines: [String] = []
        lines.append("[지금 보고 있는 명언]")
        lines.append("본문: \(context.quote.text)")
        if let original = context.quote.originalText, !original.isEmpty {
            lines.append("원문: \(original)")
        }
        lines.append("주제: \(context.quote.category.title)")

        lines.append("")
        lines.append("[작가]")
        lines.append("이름: \(context.author.displayName)")
        if !context.author.occupation.trimmed.isEmpty {
            lines.append("직업: \(context.author.occupation)")
        }
        if !context.author.nationality.trimmed.isEmpty {
            lines.append("국적: \(context.author.nationality)")
        }
        if let birth = context.author.birthYear {
            let death = context.author.deathYear.map { String($0) } ?? L("현재")
            lines.append("생몰: \(birth)–\(death)")
        }
        if let era = context.author.era, !era.trimmed.isEmpty {
            lines.append("시대: \(era.trimmed)")
        }
        if !context.author.biography.trimmed.isEmpty {
            lines.append("소개: \(context.author.biography.trimmed)")
        }
        if !context.author.achievements.isEmpty {
            lines.append("업적: \(context.author.achievements.prefix(3).joined(separator: " / "))")
        }

        if let story = context.story {
            lines.append("")
            lines.append("[앱에 준비된 배경 (사람이 쓴 확인된 자료)]")
            lines.append(story.occasion)
            lines.append(story.context)
            if let takeaway = story.takeaway, !takeaway.trimmed.isEmpty {
                lines.append(takeaway)
            }
            lines.append("출처: \(story.source)")
        }

        return lines.joined(separator: "\n")
    }

    /// 첫 화면에 띄우는 예시 질문. 사용자가 무엇을 물을 수 있는지 알려 준다.
    public static func suggestions(hasContext: Bool) -> [String] {
        var items: [String] = []
        if hasContext {
            items.append(L("이 명언의 숨은 뜻이 뭐야?"))
            items.append(L("작가의 일생을 알려 줘"))
            items.append(L("지금 내 상황에 어떻게 적용할까?"))
        } else {
            items.append(L("오늘의 명언을 풀어 줘"))
            items.append(L("요즘 힘든데, 어떤 명언이 좋을까?"))
            items.append(L("가장 오래된 명언은 뭐야?"))
        }
        return items
    }
}
