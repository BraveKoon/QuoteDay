import Foundation

/// 해설을 만들 때 기기 모델에 건네는 지시문.
///
/// 프롬프트를 한곳에 모아 두는 이유는 **테스트할 수 있게** 하기 위해서다.
/// 기기 모델은 CI 에서 돌릴 수 없지만, 프롬프트에 명언·인물·언어가 제대로
/// 들어갔는지는 순수 문자열 비교로 확인할 수 있다.
public enum QuoteExplainerPrompt {

    /// 캐시 형식이 바뀌면 올린다. 예전 해설을 그대로 보여 주지 않기 위해서다.
    public static let promptVersion = 1
    public static let modelVersion = 1

    /// 캐시 키. 명언 + 언어 + 프롬프트/모델 판.
    ///
    /// 판을 키에 넣어 두면 프롬프트를 고쳤을 때 예전 해설이 조용히 재사용되지 않는다.
    public static func cacheKey(slug: String, language: AppLanguage) -> String {
        "\(slug)|\(language.rawValue)|p\(promptVersion)m\(modelVersion)"
    }

    /// 언어마다 모델에게 그 언어로 쓰라고 알려 준다.
    public static func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .korean: "한국어 (Korean)"
        case .english: "English"
        case .simplifiedChinese: "简体中文 (Simplified Chinese)"
        case .traditionalChinese: "繁體中文 (Traditional Chinese)"
        }
    }

    /// 세션 지시문. 모델의 역할과 금지 사항을 정한다.
    public static func instructions(language: AppLanguage) -> String {
        """
        너는 오래된 명언을 오늘의 삶에 이어 주는 안내자다. 독자는 이 문장을 \
        처음 만났고, 어렵거나 뻔한 소리로 느낄 수 있다.

        규칙:
        1. 모든 답은 \(languageName(language)) 로 쓴다. 다른 언어를 섞지 않는다.
        2. 세 부분을 쓴다: 무슨 뜻인가요(summary) 2문장, 어떤 배경인가요(context) 2문장, \
        오늘 해 볼 일(practice) 1~2문장.
        3. 전체 5~6문장, 400자 안쪽. 길게 쓰지 않는다.
        4. 확인되지 않은 일화·연도·인용을 지어내지 않는다. 배경이 확실하지 않으면 \
        "이런 뜻으로 읽힌다"처럼 해석으로 말한다.
        5. 인물을 신격화하지 않는다. 설교조("~해야 합니다") 대신 담담한 말투를 쓴다.
        6. practice 는 오늘 안에 할 수 있는 아주 작은 행동 하나를 제안한다.
        7. 군더더기 인사말, 제목, 목록 기호를 붙이지 않는다.
        """
    }

    /// 이 명언에 대한 요청문.
    public static func prompt(quote: Quote, author: Author, language: AppLanguage) -> String {
        var lines: [String] = []
        lines.append("명언: \(quote.text)")
        if let original = quote.originalText, !original.isEmpty {
            lines.append("원문: \(original)")
        }
        lines.append("인물: \(author.displayName)")
        if !author.occupation.trimmed.isEmpty {
            lines.append("직업: \(author.occupation)")
        }
        if !author.nationality.trimmed.isEmpty {
            lines.append("국적: \(author.nationality)")
        }
        if let birthYear = author.birthYear {
            let death = author.deathYear.map { String($0) } ?? L("현재")
            lines.append("생몰: \(birthYear)–\(death)")
        }
        lines.append("주제: \(quote.category.title)")
        lines.append("")
        lines.append("이 명언을 위 규칙대로 해설해 줘. 답은 \(languageName(language)) 로.")
        return lines.joined(separator: "\n")
    }
}
