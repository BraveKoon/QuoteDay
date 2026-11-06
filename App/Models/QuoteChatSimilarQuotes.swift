import Foundation

/// "비슷한 뜻의 다른 명언이 있을까?" 는 **앱에 수록된 결이 비슷한 명언**으로 답한다.
///
/// 1.15.6·1.15.7 실기기 점검(Qwen3 1.7B): 두 번 다 지금 보고 있는 명언을 그대로 돌려주었다.
/// 작은 모델은 다른 명언을 떠올리지 못하고, 떠올려도 작가를 틀리게 붙이기 쉽다.
/// 앱에는 사람이 고른 명언 201편이 있다 — 그중에서 보여 주면 정확하고, 눌러서 찾아볼 수도 있다.
///
/// 고르는 기준은 **기분 꼬리표가 먼저, 주제는 그다음**이다. 1.15.8 은 주제(카테고리)만 보았는데,
/// "인간관계" 가 넓어서 우정 명언에 리더십·음식 명언이 따라 나왔다. 기분 꼬리표(`MoodLibrary`)는
/// "어떤 마음일 때 읽히는가" 로 사람이 붙인 것이라 결이 더 가깝다. 기기 내 Qwen 에만 쓴다.
enum QuoteChatSimilarQuotes {

    /// 비슷한 명언을 찾는 질문인지.
    static func matches(_ question: String) -> Bool {
        let text = question.lowercased()
        let asksForAnother = ["비슷한", "같은 뜻", "다른 명언", "비슷한 말", "相近", "相似", "类似", "類似", "其他名言", "别的名言", "別的名言"]
            .contains { text.contains($0) }
            || (text.contains("similar") || text.contains("another") || text.contains("other"))
        let aboutQuotes = ["명언", "말", "名言", "quote", "saying"].contains { text.contains($0) }
        return asksForAnother && aboutQuotes
    }

    /// 같은 주제의 다른 명언 세 편. 없으면 nil (모델에게).
    static func reply(
        to question: String,
        language: AppLanguage,
        context: QuoteChatContext?,
        library: QuoteLibrary = .shared
    ) -> String? {
        guard let context, matches(question) else { return nil }
        let picks = candidates(for: context.quote, in: library.quotes)
        guard !picks.isEmpty else { return nil }

        let lines = picks.map { quote -> String in
            let author = library.author(for: quote)
            let name = language == .english ? author.name : author.displayName
            return "\u{201C}\(quote.text)\u{201D} — \(name)"
        }
        switch language {
        case .korean:
            return "이 명언과 결이 비슷한 명언이에요.\n\n" + lines.joined(separator: "\n\n")
                + "\n\n마음에 드는 명언이 있으면 위쪽 명언을 눌러 바꾼 뒤 이어서 물어볼 수 있어요."
        case .english:
            return "Here are quotes in a similar spirit.\n\n" + lines.joined(separator: "\n\n")
                + "\n\nIf one speaks to you, tap the quote at the top to switch to it and keep asking."
        case .simplifiedChinese:
            return "这些名言和它意境相近。\n\n" + lines.joined(separator: "\n\n")
                + "\n\n如果有喜欢的，可以点按上方的名言切换过去，继续提问。"
        case .traditionalChinese:
            return "這些名言和它意境相近。\n\n" + lines.joined(separator: "\n\n")
                + "\n\n如果有喜歡的，可以點按上方的名言切換過去，繼續提問。"
        }
    }

    /// 지금 명언과 작가를 뺀 명언 중 결이 가장 가까운 세 편.
    ///
    /// 점수: 함께 붙은 기분 하나에 2점, 겹치는 주제(주·보조) 하나에 1점. 0점은 고르지 않는다.
    /// 같은 점수 안의 순서는 명언마다 정해져 있다(같은 명언에서 물으면 같은 답) — 매번
    /// 달라지면 점검 결과를 비교할 수 없다.
    static func candidates(
        for quote: Quote,
        in pool: [Quote],
        moods: [String: [QuoteMood]] = MoodLibrary.bySlug,
        count: Int = 3
    ) -> [Quote] {
        let myMoods = Set(moods[quote.slug] ?? [])
        let myTopics = Set([quote.category] + quote.secondaryCategories)
        func score(_ other: Quote) -> Int {
            let sharedMoods = myMoods.intersection(moods[other.slug] ?? []).count
            let sharedTopics = myTopics.intersection([other.category] + other.secondaryCategories).count
            return sharedMoods * 2 + sharedTopics
        }
        let seed = quote.slug.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        func tiebreak(_ other: Quote) -> Int {
            other.slug.unicodeScalars.reduce(seed) { ($0 &* 33 &+ Int($1.value)) & 0x7FFF_FFFF }
        }
        return pool
            .filter { $0.slug != quote.slug && $0.authorID != quote.authorID }
            .map { (quote: $0, score: score($0), order: tiebreak($0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .prefix(count)
            .map { $0.quote }
    }
}
