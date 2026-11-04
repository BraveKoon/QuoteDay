import Foundation

/// Qwen3 가 답하기 전에 쓰는 `<think>…</think>` 구간을 화면에서 걷어낸다.
///
/// Qwen3 는 기본이 **생각하는 모드**다. 답하기 전에 영어로 혼잣말을 길게 쓰고,
/// 작은 모델(0.6B)은 그 안에서 같은 문장을 되풀이하며 빠져나오지 못한다. 사용자가
/// 본 것이 정확히 그것이다 — 질문은 한국어인데 화면에는 영어 독백이 흘렀다.
///
/// 1차로 프롬프트에 `/no_think` 를 붙여 모델이 생각을 건너뛰게 하지만, 그것은
/// 부탁이지 보장이 아니다(작은 모델일수록 어긴다). 그래서 **출력 쪽에서도 구조로
/// 막는다.** 이 타입은 조각이 흘러 들어오는 대로 생각 구간을 버리고 답만 내보낸다.
///
/// 조각은 아무 데서나 끊긴다 — `</thi` 와 `nk>` 로 나뉘어 올 수 있다. 그래서
/// 표시일 수도 있는 끝부분은 다음 조각이 올 때까지 쥐고 있는다.
public struct QwenThinkingFilter: Sendable {
    private static let open = "<think>"
    private static let close = "</think>"

    /// 아직 판단하지 못한 끝부분. 표시의 앞머리일 수 있어서 쥐고 있다.
    private var pending = ""
    private var isThinking = false
    /// 보여 줄 글자를 하나라도 내보냈는지. 그 전까지는 앞쪽 공백을 버린다.
    private var hasEmitted = false

    public init() {}

    /// 조각 하나를 넣고, 지금 화면에 보여도 되는 글자를 돌려준다.
    public mutating func feed(_ chunk: String) -> String {
        pending += chunk
        var output = ""

        while true {
            if isThinking {
                if let range = pending.range(of: Self.close) {
                    pending.removeSubrange(pending.startIndex..<range.upperBound)
                    isThinking = false
                    continue
                }
                // 닫는 표시가 아직 안 왔다. 생각은 버리되, 끝에 걸쳐 온 표시의
                // 앞머리만 남긴다.
                pending = Self.partialSuffix(of: pending, matching: Self.close)
                break
            }

            if let range = pending.range(of: Self.open) {
                output += pending[pending.startIndex..<range.lowerBound]
                pending.removeSubrange(pending.startIndex..<range.upperBound)
                isThinking = true
                continue
            }

            let held = Self.partialSuffix(of: pending, matching: Self.open)
            output += pending.dropLast(held.count)
            pending = held
            break
        }

        return trimLeading(output)
    }

    /// 흐름이 끝났다. 쥐고 있던 글자를 내보낸다.
    ///
    /// 생각 구간 안에서 끝났다면(토큰 한도에 걸린 경우) 보여 줄 것이 없다.
    /// 그때는 빈 문자열이 가고, 엔진이 "답이 오지 않았어요" 를 띄운다.
    public mutating func finish() -> String {
        let rest = isThinking ? "" : pending
        pending = ""
        return trimLeading(rest)
    }

    /// 생각 구간을 닫고 나면 템플릿이 남긴 빈 줄이 맨 앞에 온다. 첫 글자 전의
    /// 공백만 버린다 — 답 중간의 줄바꿈은 그대로 둔다.
    private mutating func trimLeading(_ text: String) -> String {
        guard !hasEmitted else { return text }
        let trimmed = String(text.drop(while: { $0.isWhitespace || $0.isNewline }))
        if !trimmed.isEmpty { hasEmitted = true }
        return trimmed
    }

    /// `text` 의 끝부분 중 `tag` 의 앞머리와 같은 가장 긴 것.
    private static func partialSuffix(of text: String, matching tag: String) -> String {
        let longest = min(text.count, tag.count - 1)
        guard longest > 0 else { return "" }
        for length in stride(from: longest, through: 1, by: -1) {
            let suffix = String(text.suffix(length))
            if tag.hasPrefix(suffix) { return suffix }
        }
        return ""
    }
}
