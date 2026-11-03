import Foundation

/// AI 대화를 누구에게 물어볼지.
///
/// 통로를 둘로 줄였다. 예전에는 사용자가 발급한 **API 키로 클라우드 Qwen** 을
/// 부르는 길도 있었지만 걷어냈다. 이유는 세 가지다.
/// - **키를 넣게 하는 일 자체가 부담**이다. 발급·결제·보관을 사용자가 떠안는다.
/// - **질문이 기기 밖으로 나간다.** 명언 감상에 곁들인 사적인 이야기가 서버로
///   가는 통로를 앱이 열어 두는 값이, 얻는 것보다 크다고 판단했다.
/// - Qwen 은 이미 **기기 안에서** 돌린다(오픈소스 가중치). 같은 모델을 클라우드로
///   부르는 두 번째 길은 유지비만 늘렸다.
///
/// 그래서 지금은 둘 다 **기기 안에서** 끝난다. 인터넷·키·요금이 필요 없다.
public enum AIChatProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Apple Foundation Models. OS 가 준비한 모델이라 내려받기가 필요 없다.
    case onDevice
    /// Qwen3 오픈소스 가중치를 기기에서 직접 돌린다. 처음 한 번 내려받는다.
    case localQwen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onDevice: L("온디바이스 (무료)")
        case .localQwen: L("Qwen3 기기 내 (오픈소스)")
        }
    }

    public var detail: String {
        switch self {
        case .onDevice:
            L("기기 안에서 답해요. 인터넷도, 키도, 요금도 필요 없어요.")
        case .localQwen:
            L("Qwen3 가중치를 내려받아 기기에서 직접 돌려요. 질문이 나가지 않고, 키도 요금도 없어요.")
        }
    }

    public var symbol: String {
        switch self {
        case .onDevice: "iphone.gen3"
        case .localQwen: "cpu"
        }
    }

    /// 이 통로를 쓰려면 모델을 내려받아야 하는지.
    public var requiresModelDownload: Bool { self == .localQwen }

    /// 질문이 기기 밖으로 나가는지.
    ///
    /// 지금은 **어떤 통로도 나가지 않는다.** 화면에 적을 문구를 한곳에서 정하려고
    /// 남겨 둔 값이다. 나중에 서버 통로를 다시 넣는다면 여기만 바꾸면 안내가 따라온다.
    public var leavesDevice: Bool { false }
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
