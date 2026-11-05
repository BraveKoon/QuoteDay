import Foundation

/// 모델의 답이 **앱 언어로 시작하는지** 판정한다.
///
/// 실기기에서 한국어 화면의 AI 가 `넌 누구야`, `야` 같은 일상 말에 똑같은 영어 문장
/// ("I'm a language model developed by the company…")을 내놓았다. 같은 대화에서 `안녕` 에는
/// 한국어로 답했다 — 규칙을 모르는 게 아니라 **일상 대화에서만 외운 영어 답으로 도망간다.**
/// 프롬프트로 줄일 수는 있어도 작은 모델에게 보장은 못 받는다. 그래서 출력 쪽에서도
/// 구조로 막는다(`QwenThinkingFilter` 가 생각 구간을 막는 것과 같은 이유다).
///
/// 앞부분(글자 12개)을 쥐고 있다가 판정한다. 틀렸으면 **화면에 한 글자도 내보내지 않고**
/// 버린다. 맞으면 쥐고 있던 것을 한꺼번에 내보내고 그 뒤는 그대로 흘린다.
public struct ReplyLanguageGuard: Sendable {
    public enum Verdict: Equatable, Sendable {
        /// 아직 판단할 글자가 모자란다. 내보내지 말고 기다린다.
        case hold
        /// 이 글자를 화면에 내보낸다.
        case release(String)
        /// 앱 언어가 아니다. 이 답은 버린다.
        case reject
    }

    /// 판정에 필요한 글자 수. 너무 적으면 `AI` 같은 영어 낱말 하나에 오판한다.
    static let letterThreshold = 12
    /// 이보다 짧게 끝난 답은 **글자가 이만큼 이상일 때만** 판정한다.
    /// (`OK` 같은 한 마디를 틀렸다고 버리지 않는다.)
    static let shortReplyThreshold = 4

    /// 왜 버렸는지. 화면에 띄울 안내가 달라진다.
    public enum Rejection: Equatable, Sendable {
        /// 앱 언어가 아니다.
        case wrongLanguage
        /// 질문을 그대로 되받았다. (1.15.4 실기기: `야` 에 `야`, 그 뒤로 모든 답이 `야`)
        case echo
    }

    private let expected: AppLanguage
    /// 사용자가 방금 한 말. 답이 이것과 같으면 답이 아니다.
    private let question: String
    private var buffer = ""
    private var decided = false
    public private(set) var rejection: Rejection?

    public init(expected: AppLanguage, question: String = "") {
        self.expected = expected
        self.question = Self.normalized(question)
    }

    public mutating func feed(_ chunk: String) -> Verdict {
        if decided { return .release(chunk) }
        buffer += chunk
        guard Self.letters(in: buffer) >= Self.letterThreshold else { return .hold }
        decided = true
        let text = buffer
        buffer = ""
        return judge(text)
    }

    /// 흐름이 끝났다. 판정하지 못한 짧은 답이 남아 있으면 마지막으로 본다.
    public mutating func finish() -> Verdict {
        if decided { return .release("") }
        decided = true
        let text = buffer
        buffer = ""
        if isEcho(text) {
            rejection = .echo
            return .reject
        }
        guard Self.letters(in: text) >= Self.shortReplyThreshold else { return .release(text) }
        return judge(text)
    }

    private mutating func judge(_ text: String) -> Verdict {
        if isEcho(text) {
            rejection = .echo
            return .reject
        }
        if !Self.matches(text, expected: expected) {
            rejection = .wrongLanguage
            return .reject
        }
        return .release(text)
    }

    /// 답이 질문을 그대로 되받았는지. 띄어쓰기·문장 부호·대소문자는 보지 않는다.
    private func isEcho(_ text: String) -> Bool {
        !question.isEmpty && Self.normalized(text) == question
    }

    /// 글자와 숫자만 남기고 소문자로.
    static func normalized(_ text: String) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars
        where scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
            kept.append(scalar)
        }
        return String(kept)
    }

    // MARK: - 판정

    /// 글자(`isLetter`) 개수. 공백·숫자·기호는 세지 않는다.
    static func letters(in text: String) -> Int {
        text.unicodeScalars.filter { $0.properties.isAlphabetic }.count
    }

    /// 글자 중 앱 언어의 문자가 충분한 비율인지.
    ///
    /// 중국어는 간체·번체를 가르지 않는다 — 한자 여부만 본다. 번체 화면에서 간체로
    /// 답하는 것은 이 가드가 잡을 일이 아니다.
    static func matches(_ text: String, expected: AppLanguage) -> Bool {
        let scalars = text.unicodeScalars.filter { $0.properties.isAlphabetic }
        guard !scalars.isEmpty else { return true }
        let total = Double(scalars.count)

        switch expected {
        case .korean:
            // 한국어 답에는 영어 낱말이 섞일 수 있다(`AI`, 고유명사). 20% 면 넉넉하다.
            return Double(scalars.filter(isHangul).count) / total >= 0.2
        case .simplifiedChinese, .traditionalChinese:
            return Double(scalars.filter(isHan).count) / total >= 0.2
        case .english:
            // 영어 화면의 답은 대부분 라틴 글자여야 한다. 한글·한자가 우세하면 틀린 것이다.
            return Double(scalars.filter(isLatin).count) / total >= 0.5
        }
    }

    private static func isHangul(_ scalar: Unicode.Scalar) -> Bool {
        (0xAC00...0xD7A3).contains(scalar.value)
            || (0x1100...0x11FF).contains(scalar.value)
            || (0x3130...0x318F).contains(scalar.value)
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }

    private static func isLatin(_ scalar: Unicode.Scalar) -> Bool {
        (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
            || (0xC0...0x24F).contains(scalar.value)
    }
}
