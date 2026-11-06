import Foundation

/// 답이 **명언 본문을 그대로 옮겨 적으며 시작하면** 그 부분을 떼어 낸다.
///
/// 1.15.6·1.15.7 실기기 점검(Qwen3 1.7B): "숨은 뜻이 뭐야?", "내 상황에 어떻게 적용할까?" 의 답이
/// 매번 `친구야말로 자연의 걸작이라 할 만하다.` 로 시작했다. 사용자는 그 명언을 이미 화면 위에서
/// 보고 있다. 질문 옆에 명언을 붙여 보내므로(`localPrompt`) 작은 모델이 그것을 먼저 베끼는 것이다.
///
/// 앞부분이 명언의 앞부분과 같은 동안은 쥐고 있다가, 명언이 끝까지 같으면 버리고 나머지를
/// 내보낸다. 중간에 달라지면 쥐고 있던 것을 그대로 내보낸다. 명언**만** 적고 끝난 답은
/// 손대지 않고 넘긴다 — 그건 `ReplyLanguageGuard` 가 되받기로 거른다.
struct QuotePrefixFilter {
    private let quote: String
    private var buffer = ""
    private var decided = false

    init(quote: String) {
        self.quote = ReplyLanguageGuard.normalized(quote)
    }

    mutating func feed(_ chunk: String) -> String {
        if decided || quote.isEmpty { return chunk }
        buffer += chunk
        let key = ReplyLanguageGuard.normalized(buffer)
        if key.isEmpty || quote.hasPrefix(key) {
            // 아직 명언을 따라 적는 중이거나, 명언을 막 다 적었다. 뒤를 보아야 안다.
            return ""
        }
        decided = true
        let text = buffer
        buffer = ""
        guard key.hasPrefix(quote) else { return text }
        return Self.dropLeading(quote, from: text)
    }

    mutating func finish() -> String {
        defer { buffer = "" }
        if decided { return "" }
        decided = true
        return buffer
    }

    /// `text` 의 앞에서 정규화했을 때 `quote` 에 해당하는 만큼을 떼고, 남은 앞 공백·문장 부호를 다듬는다.
    static func dropLeading(_ normalizedQuote: String, from text: String) -> String {
        var counted = 0
        let target = normalizedQuote.unicodeScalars.count
        var index = text.startIndex
        while index < text.endIndex, counted < target {
            counted += ReplyLanguageGuard.normalized(String(text[index])).unicodeScalars.count
            index = text.index(after: index)
        }
        let rest = text[index...].drop { $0.isWhitespace || $0.isPunctuation || "\u{201C}\u{201D}\"'—-·".contains($0) }
        return String(rest)
    }
}
