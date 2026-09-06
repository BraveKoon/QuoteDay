import Foundation

/// 널리 인용되지만 **누가 말했는지 확인되지 않은** 명언 목록.
///
/// 명언집이 조용히 틀린 역사를 가르치는 가장 흔한 경로가 오귀속이다.
/// 특히 챌린지의 "누가 말했을까"는 정답을 하나로 못 박는 형식이라,
/// 여기에 든 명언을 문제로 내면 앱이 확인되지 않은 귀속을 정답이라고 가르치게 된다.
/// 그래서 그 모드에서는 이 목록을 제외한다.
///
/// **명언 자체를 지우지는 않는다.** 문장이 나쁜 것이 아니라 꼬리표가 불확실할 뿐이고,
/// "빈칸 채우기"처럼 인물을 묻지 않는 문제에는 그대로 쓸 수 있다.
///
/// 목록에 넣는 기준은 하나다 — **1차 출처를 찾지 못했다.**
/// 나중에 출처가 확인되면 여기서 빼고 `BehindStoryLibrary` 에 배경을 넣으면 된다.
public enum DisputedAttribution {

    /// 귀속이 확인되지 않은 명언의 `Quote.slug`.
    ///
    /// 대표적인 사례:
    /// - `churchill-courage-to-continue`: 처칠이 말했다는 기록이 없다.
    ///   가장 이른 형태는 1938년 버드와이저 신문 광고 문안으로 확인된다.
    /// - `lincoln-sharpen-the-axe`: 링컨의 어떤 글이나 연설에도 없다. 1950년대에 처음 등장한다.
    /// - `mead-small-group-of-citizens`: 미드의 유고를 관리하는 연구소가 출처를 찾지 못했다고 밝혔다.
    /// - `edison-ten-thousand-ways`: 에디슨이 실패 횟수를 말한 기록은 있으나 "1만 가지"는 후대의 각색이다.
    /// - `curie-nothing-to-be-feared`: 1952년 이전의 출처가 확인되지 않는다.
    /// - `rumi-changing-myself`: 영어로 도는 루미 문장 상당수가 원문 번역이 아니라 현대의 자유로운 각색이다.
    /// - `lombardi-fatigue-makes-cowards`: 롬바르디보다 앞선 용례가 여럿 있다.
    public static let slugs: Set<String> = [
        "churchill-courage-to-continue",
        "lincoln-sharpen-the-axe",
        "ford-think-you-can",
        "ford-working-together",
        "franklin-fail-to-prepare",
        "franklin-investment-in-knowledge",
        "mead-small-group-of-citizens",
        "roosevelt-e-without-your-consent",
        "gandhi-learn-as-if-forever",
        "confucius-does-not-matter-how-slowly",
        "seneca-luck-preparation-opportunity",
        "jung-what-i-choose-to-become",
        "feynman-questions-unanswered",
        "schweitzer-happiness-is-good-health",
        "shaw-we-dont-stop-playing",
        "dewey-education-is-life",
        "mandela-language-of-the-heart",
        "davinci-learning-never-exhausts",
        "sagan-somewhere-something-incredible",
        "dalailama-not-getting-what-you-want",
        "picasso-every-child-artist",
        "keller-together-so-much",
        "keller-face-to-the-sunshine",
        "nightingale-no-excuses",
        "tolstoy-change-himself",
        "rumi-changing-myself",
        "lombardi-fatigue-makes-cowards",
        "edison-ten-thousand-ways",
        "curie-nothing-to-be-feared",
        "anne-frank-improve-the-world"
    ]

    public static func isDisputed(_ quoteSlug: String) -> Bool {
        slugs.contains(quoteSlug)
    }

    /// 인물을 정답으로 물어도 되는 명언만 남긴다.
    public static func attributable(_ quotes: [Quote]) -> [Quote] {
        quotes.filter { !slugs.contains($0.slug) }
    }
}
