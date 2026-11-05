import Foundation

/// 인사·"넌 누구야"·웃음 같은 **일상 말은 모델에게 보내지 않고 앱이 답한다.**
///
/// 1.15.5 실기기 점검(Qwen3 1.7B, 한국어)에서 무너진 곳이 정확히 여기였다.
///
/// - `안녕` → 두 번 다 `안녕` 을 되받아 답을 못 냈다.
/// - `야` → "야는 랠프 월도 에머슨의 친구야." (`야` 를 낱말로 읽고 명언 `친구야말로` 와 엮었다)
/// - `넌 누구야` → "나는 랠프 월도 에머슨의 친구야.", 다른 때는 `Quote0.4/1.7/4`
///
/// 예시 대화(1.15.4)도, 언어 지시도 이 자리를 고치지 못했다. 작은 모델에게 짧은 일상 말은
/// 붙잡을 내용이 없어서, 질문 옆의 명언 문장을 아무렇게나 끌어다 쓴다. 이런 말에 돌려줄
/// 답은 사실 몇 가지뿐이고 정해져 있다 — 모델을 부를 이유가 없다. 정해진 답이 빠르고,
/// 틀리지 않고, 사용자를 명언 이야기로 데려간다.
///
/// **기기 내 Qwen 에만 쓴다.** Apple 온디바이스 모델은 이런 말을 잘 받는다.
/// 고르는 기준은 일부러 좁다. 애매하면 모델에게 넘긴다 — 진짜 질문을 앱이 가로채면
/// 그쪽이 더 나쁘다.
enum QuoteChatSmallTalk {

    enum Kind: Equatable {
        case greeting
        case identity
        case call
        /// 웃음·자모만 친 말·자판 두드림
        case noise
    }

    /// 일상 말이면 그 종류, 아니면 nil (모델에게 보낸다).
    static func classify(_ text: String) -> Kind? {
        let trimmed = text.trimmed
        let key = ReplyLanguageGuard.normalized(trimmed)

        // 글자가 하나도 없다(기호·이모지뿐).
        if key.isEmpty { return trimmed.isEmpty ? nil : .noise }
        if identities.contains(key) { return .identity }
        if greetings.contains(key) { return .greeting }
        if calls.contains(key) { return .call }
        if isNoise(key) { return .noise }
        return nil
    }

    /// 정해진 답. 일상 말이 아니면 nil.
    static func reply(to text: String, language: AppLanguage, context: QuoteChatContext?) -> String? {
        guard let kind = classify(text) else { return nil }
        let author = context.map { authorName($0.author, language: language) }
        return answer(kind, language: language, author: author)
    }

    // MARK: - 고르기

    private static let greetings: Set<String> = [
        "안녕", "안녕하세요", "안녕하십니까", "안뇽", "안녕안녕", "반가워", "반가워요", "반갑습니다",
        "하이", "하이요", "헬로", "방가", "방가방가", "좋은아침", "굿모닝",
        "hi", "hello", "hiya", "hithere", "hellothere", "heythere", "goodmorning", "goodevening",
        "你好", "您好", "嗨", "哈喽", "哈囉", "早上好", "早安"
    ]

    private static let identities: Set<String> = [
        "넌누구야", "너누구야", "누구야", "누구세요", "누구니", "너는누구니", "넌누구니", "너는누구야",
        "넌뭐야", "너뭐야", "너는뭐야", "이름이뭐야", "너이름이뭐야", "네이름이뭐야", "넌누구세요",
        "당신은누구인가요", "당신은누구세요", "누구신가요",
        "whoareyou", "whatareyou", "whatsyourname", "whatisyourname", "whoru", "whoisthis",
        "你是谁", "你是誰", "你是什么", "你是什麼", "你叫什么名字", "你叫什麼名字", "你叫什么", "你叫什麼"
    ]

    private static let calls: Set<String> = [
        "야", "얌", "저기", "저기요", "여보세요", "있어", "있어요", "거기있어", "거기있어요", "어이",
        "hey", "yo", "heyyou", "anyonethere", "areyouthere",
        "喂", "在吗", "在嗎", "在不在", "哈罗"
    ]

    /// 웃음, 자모만 친 말, 같은 글자 되풀이, 자판 두드림.
    private static func isNoise(_ key: String) -> Bool {
        let scalars = Array(key.unicodeScalars)
        // 홀로 선 자모(ㅋ, ㅎ, ㅠ, ㅗ …)가 하나라도 있고 짧으면 칠 말을 다 치지 않은 것이다.
        // (`홀롤ㅗ`, `ㅋㅋㅋ`, `ㅠㅠ`) 실제 질문에는 자모가 홀로 들어가지 않는다.
        let jamo = scalars.filter { (0x3131...0x318E).contains($0.value) }.count
        if jamo > 0, scalars.count <= 8 { return true }

        // 같은 글자 되풀이는 일부러 일반 규칙으로 두지 않는다. `谢谢`(고마워)·`哈哈` 처럼
        // 겹글자가 뜻을 갖는 말이 있다. 웃음은 아래 목록으로만 고른다.
        let laughs: Set<String> = [
            "ㅋㅋ", "lol", "lmao", "haha", "hahaha", "hehe", "hihi", "asdf", "qwer", "qwerty",
            "哈哈", "哈哈哈", "呵呵", "嘿嘿", "嘻嘻", "啊啊", "啊啊啊"
        ]
        if laughs.contains(key) { return true }
        // `hahahaha`, `lololol` 처럼 두 글자가 번갈아 되풀이.
        if scalars.count >= 4, Set(scalars).count == 2, key.hasPrefix("ha") || key.hasPrefix("lo") || key.hasPrefix("he") {
            return true
        }
        return false
    }

    // MARK: - 답

    private static func authorName(_ author: Author, language: AppLanguage) -> String {
        let localized = author.localized(in: language)
        return language == .english ? localized.name : localized.displayName
    }

    private static func answer(_ kind: Kind, language: AppLanguage, author: String?) -> String {
        switch language {
        case .korean:
            switch kind {
            case .greeting:
                return author.map { "안녕하세요! 지금 보고 있는 건 \($0)의 명언이에요. 숨은 뜻이나 \($0)의 삶이 궁금하면 편하게 물어보세요." }
                    ?? "안녕하세요! 명언의 숨은 뜻이나 작가 이야기가 궁금하면 편하게 물어보세요."
            case .identity:
                return "저는 QuoteDay 의 명언 안내자예요. 이 기기 안에서만 돌아가는 AI 라서 나눈 이야기가 밖으로 나가지 않아요. 명언의 뜻, 작가의 삶, 지금 내 상황에 어떻게 적용할지를 함께 볼 수 있어요."
            case .call:
                return "네, 듣고 있어요. 이 명언에 대해 궁금한 걸 물어보세요."
            case .noise:
                return "무엇이 궁금한지 조금만 더 알려 주세요. 예를 들어 \"이 명언의 숨은 뜻이 뭐야?\" 처럼 물어봐도 좋아요."
            }
        case .english:
            switch kind {
            case .greeting:
                return author.map { "Hello! You're looking at a quote by \($0). Ask me anything about its meaning or about \($0)'s life." }
                    ?? "Hello! Ask me anything about a quote's meaning or its author."
            case .identity:
                return "I'm the quote guide inside QuoteDay. I run only on this device, so nothing we talk about leaves it. I can help you explore a quote's meaning, its author's life, and how it might apply to you."
            case .call:
                return "Yes, I'm here. What would you like to know about this quote?"
            case .noise:
                return "Tell me a little more about what you'd like to know. For example, you could ask \"What is the hidden meaning of this quote?\""
            }
        case .simplifiedChinese:
            switch kind {
            case .greeting:
                return author.map { "你好！你正在看的是\($0)的名言。想了解它的含义或\($0)的人生，尽管问我。" }
                    ?? "你好！想了解名言的含义或作者的故事，尽管问我。"
            case .identity:
                return "我是 QuoteDay 里的名言向导，只在这台设备上运行，我们的对话不会离开设备。我可以和你一起看名言的含义、作者的人生，以及它和你现在的处境有什么关系。"
            case .call:
                return "我在。想了解这句名言的什么？"
            case .noise:
                return "能再多说一点你想了解什么吗？比如可以问：“这句名言隐藏的意思是什么？”"
            }
        case .traditionalChinese:
            switch kind {
            case .greeting:
                return author.map { "你好！你正在看的是\($0)的名言。想了解它的含義或\($0)的人生，儘管問我。" }
                    ?? "你好！想了解名言的含義或作者的故事，儘管問我。"
            case .identity:
                return "我是 QuoteDay 裡的名言嚮導，只在這台裝置上執行，我們的對話不會離開裝置。我可以和你一起看名言的含義、作者的人生，以及它和你現在的處境有什麼關係。"
            case .call:
                return "我在。想了解這句名言的什麼？"
            case .noise:
                return "能再多說一點你想了解什麼嗎？比如可以問：「這句名言隱藏的意思是什麼？」"
            }
        }
    }
}
