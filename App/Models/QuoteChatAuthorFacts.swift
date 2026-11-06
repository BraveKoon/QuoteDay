import Foundation

/// 작가의 **국적·생몰·직업·일생** 을 묻는 질문은 모델에게 보내지 않고 **앱 자료로** 답한다.
///
/// 1.15.6 실기기 점검(Qwen3 1.7B, 한국어)에서 앱 자료가 질문 바로 옆에 있었는데도:
///
/// - `작가는 어느 나라 사람이야?` → "한국어로: 한국 사람이야." (자료: 미국)
/// - `작가의 일생을 알려 줘` → 태어난 날·곳·전공을 지어냈다
///   ("1803년 11월 15일, 뉴욕주 레이크포어" — 실제로는 5월 25일 보스턴)
///
/// 작은 모델은 사실을 지킬 수 없다. 앱에는 사람이 쓰고 확인한 인물 자료가 있으므로
/// 그것을 그대로 보여 주는 편이 정확하고 빠르다. 해석이 필요한 질문("작가의 삶이 이 명언에
/// **어떻게** 드러나?")은 가로채지 않는다 — `왜·어떻게·뜻·명언` 같은 말이 들어 있으면 넘긴다.
///
/// 기기 내 Qwen 에만 쓴다.
enum QuoteChatAuthorFacts {

    enum Topic: Equatable {
        case nationality
        case lifespan
        case occupation
        case profile
    }

    /// 작가 사실을 묻는 질문이면 그 주제, 아니면 nil.
    static func classify(_ question: String, author: Author? = nil) -> Topic? {
        let text = question.lowercased()
        let words = Set(text.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init))
        func has(_ markers: [String]) -> Bool { markers.contains { text.contains($0) } }
        func hasWord(_ markers: [String]) -> Bool { markers.contains { words.contains($0) } }

        // 해석을 묻는 질문은 모델에게.
        if has(["왜", "어떻게", "뜻", "명언", "영향", "관계", "의미", "为什么", "為什麼", "怎么", "怎麼", "意思", "名言", "影响", "影響"])
            || hasWord(["why", "how", "mean", "meaning", "quote", "influence", "relate"]) {
            return nil
        }

        // 작가를 가리켜야 한다. "어느 나라 사람이야?" 만으로는 누구 이야기인지 모른다.
        var references = ["작가", "저자", "이 사람", "그 사람", "이분", "그분", "作者", "作家"]
        if let author {
            references += author.name.lowercased().split(separator: " ").map(String.init).filter { $0.count >= 3 }
            if let korean = author.koreanName {
                references += korean.split(separator: " ").map(String.init).filter { $0.count >= 2 }
            }
        }
        let refersToAuthor = has(references) || has(["author", "writer"])
        guard refersToAuthor else { return nil }

        if has(["나라", "국적", "출신", "어디 사람", "国", "國", "哪里人", "哪裡人"])
            || hasWord(["country", "nationality"]) || (words.contains("where") && words.contains("from")) {
            return .nationality
        }
        if has(["태어", "출생", "생년", "죽었", "사망", "돌아가", "몇 살", "생몰", "언제 살", "出生", "去世", "逝世", "哪年", "生卒"])
            || hasWord(["born", "die", "died", "death", "lived", "old"]) {
            return .lifespan
        }
        if has(["직업", "무슨 일", "뭐 하던", "뭐하던", "뭐 한 사람", "어떤 일", "职业", "職業", "做什么", "做什麼"])
            || hasWord(["job", "occupation", "profession", "work"]) {
            return .occupation
        }
        if has(["일생", "생애", "인생", "삶", "어떤 사람", "누구야", "누구예요", "누군지", "소개", "一生", "生平", "是谁", "是誰", "介绍", "介紹"])
            || hasWord(["life", "biography", "who"]) {
            return .profile
        }
        return nil
    }

    /// 앱 자료로 만든 답. 주제가 아니거나, 그 언어로 보여 줄 자료가 없으면 nil (모델에게).
    static func reply(to question: String, language: AppLanguage, context: QuoteChatContext?) -> String? {
        guard let context, let topic = classify(question, author: context.author) else { return nil }
        let author = context.author.localized(in: language)

        /// 이 언어로 번역된 값만 쓴다. 번역이 없으면 한국어 원문이 돌아오는데,
        /// 영어 화면에 한국어 소개를 보이느니 모델에게 넘긴다.
        func usable(_ value: String) -> String? {
            let value = value.trimmed
            guard !value.isEmpty else { return nil }
            return ReplyLanguageGuard.matches(value, expected: language) ? value : nil
        }

        let name = language == .english ? author.name : author.displayName
        let nationality = usable(author.nationality)
        let occupation = usable(author.occupation)
        let biography = usable(author.biography)
        let achievements = author.achievements.compactMap(usable)
        let present = L("현재", language: language)
        let years: String? = author.birthYear.map { birth in
            "\(birth)–\(author.deathYear.map(String.init) ?? present)"
        }

        // 물은 것에 답할 자료가 없으면 앱이 답하지 않는다. 국적을 물었는데 생몰년만 보여 주면 답이 아니다.
        switch topic {
        case .nationality: guard nationality != nil else { return nil }
        case .lifespan: guard years != nil else { return nil }
        case .occupation: guard occupation != nil else { return nil }
        case .profile: break
        }

        switch language {
        case .korean:
            return korean(topic, name: name, author: author, nationality: nationality,
                          occupation: occupation, biography: biography, achievements: achievements, years: years)
        case .english, .simplifiedChinese, .traditionalChinese:
            var lines: [String] = []
            let labels = Self.labels(language)
            if let nationality { lines.append("\(labels.country)\(nationality)") }
            if let years { lines.append("\(labels.years)\(years)") }
            if let occupation { lines.append("\(labels.knownAs)\(occupation)") }
            guard !lines.isEmpty else { return nil }
            var text = labels.header(name) + "\n" + lines.joined(separator: "\n")
            if topic == .profile, let biography { text += "\n\n" + biography }
            if topic == .profile, !achievements.isEmpty {
                text += "\n\n" + labels.works + achievements.prefix(3).joined(separator: ", ")
            }
            return text
        }
    }

    // MARK: - 한국어 문장

    private static func korean(
        _ topic: Topic, name: String, author: Author, nationality: String?, occupation: String?,
        biography: String?, achievements: [String], years: String?
    ) -> String? {
        let subject = name + josa(name, "은", "는")
        switch topic {
        case .nationality:
            guard let nationality else { return nil }
            var text = "\(subject) \(nationality) 사람이에요."
            if let occupation { text += " \(occupation)\(josaRo(occupation)) 알려져 있어요." }
            return text
        case .lifespan:
            guard let birth = author.birthYear else { return nil }
            if let death = author.deathYear {
                return "\(subject) \(birth)년에 태어나 \(death)년에 세상을 떠났어요."
            }
            return "\(subject) \(birth)년에 태어났어요."
        case .occupation:
            guard let occupation else { return nil }
            let place = nationality.map { "\($0)의 " } ?? ""
            return "\(subject) \(place)\(occupation)\(josa(occupation, "이에요", "예요"))."
        case .profile:
            let facts = [years, nationality, occupation].compactMap { $0 }
            guard !facts.isEmpty || biography != nil else { return nil }
            var text = facts.isEmpty ? name : "\(name) · \(facts.joined(separator: " · "))"
            if let biography { text += "\n\n" + biography }
            if !achievements.isEmpty { text += "\n\n대표작·업적: " + achievements.prefix(3).joined(separator: ", ") }
            text += "\n\n이 명언과 어떻게 이어지는지 궁금하면 이어서 물어보세요."
            return text
        }
    }

    /// 마지막 글자에 받침이 있으면 `withFinal`, 없으면 `withoutFinal`.
    static func josa(_ word: String, _ withFinal: String, _ withoutFinal: String) -> String {
        guard let last = word.trimmed.unicodeScalars.last(where: { $0.properties.isAlphabetic }),
              (0xAC00...0xD7A3).contains(last.value) else { return withFinal }
        return (last.value - 0xAC00) % 28 == 0 ? withoutFinal : withFinal
    }

    /// `으로/로`. 받침이 없거나 ㄹ 받침이면 `로`.
    static func josaRo(_ word: String) -> String {
        guard let last = word.trimmed.unicodeScalars.last(where: { $0.properties.isAlphabetic }),
              (0xAC00...0xD7A3).contains(last.value) else { return "으로" }
        let final = (last.value - 0xAC00) % 28
        return final == 0 || final == 8 ? "로" : "으로"
    }

    // MARK: - 다른 언어의 표

    private struct Labels {
        let header: (String) -> String
        let country: String
        let years: String
        let knownAs: String
        let works: String
    }

    private static func labels(_ language: AppLanguage) -> Labels {
        switch language {
        case .simplifiedChinese:
            return Labels(header: { "关于\($0)，QuoteDay 收录的资料：" },
                          country: "国家：", years: "生卒：", knownAs: "身份：", works: "代表作与成就：")
        case .traditionalChinese:
            return Labels(header: { "關於\($0)，QuoteDay 收錄的資料：" },
                          country: "國家：", years: "生卒：", knownAs: "身分：", works: "代表作與成就：")
        case .english, .korean:
            return Labels(header: { "Here's what QuoteDay has on \($0):" },
                          country: "Country: ", years: "Years: ", knownAs: "Known as: ", works: "Notable works: ")
        }
    }
}

/// 앱이 직접 답하는 질문 전체(일상 말 + 작가 사실 + 비슷한 명언). 기기 내 Qwen 통로와 모델 점검이 같이 쓴다.
enum QuoteChatAppAnswer {
    static func reply(to question: String, language: AppLanguage, context: QuoteChatContext?) -> String? {
        QuoteChatSmallTalk.reply(to: question, language: language, context: context)
            ?? QuoteChatAuthorFacts.reply(to: question, language: language, context: context)
            ?? QuoteChatSimilarQuotes.reply(to: question, language: language, context: context)
    }
}
