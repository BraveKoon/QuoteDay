import Foundation

/// 기기 안의 AI 가 **실제로 어떻게 답하는지** 한 번에 돌려 보는 점검의 규칙.
///
/// 이 모델은 시뮬레이터에서도 CI 에서도 돌지 않는다(MLX 는 Metal 이 필요하다). 그래서 답이
/// 어떤지는 **실기기에서만** 알 수 있고, 개발하는 쪽은 화면 캡처 한두 장을 보고 추측해서
/// 고쳐 왔다. 같은 질문 열 개를 한 번에 돌려 결과를 복사해 보낼 수 있으면, 추측 대신 실제
/// 출력으로 다음 수정을 정할 수 있다.
///
/// 질문은 **실제 대화와 같은 길**(`QuoteChatPrompt.system` + `LocalQwenChatTransport`)로
/// 보낸다. 점검이 실제와 다른 프롬프트로 돌면 결과가 아무것도 말해 주지 못한다.
enum QwenDiagnostic {

    /// TestFlight(또는 개발 설치)에서만 켠다. App Store 판 영수증은 `receipt`,
    /// TestFlight·개발 설치는 `sandboxReceipt` 다.
    static var isAvailable: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// 점검에 쓰는 질문. 일상 말·무의미한 입력·실제 질문을 섞는다 — 실기기에서 무너진 곳이
    /// 일상 말이었다(`넌 누구야`, `야` 에 똑같은 영어 문장).
    static func prompts(language: AppLanguage) -> [String] {
        // 1·2번은 일상 말, 5·6번은 작가 사실, 8번은 비슷한 명언 — 앱이 답한다(가로채기가 작동하는지 본다).
        // 3·4·7번은 모델이 답하고, 4번은 3번을 이어 받는다.
        switch language {
        case .korean:
            return ["안녕", "넌 누구야", "이 명언의 숨은 뜻이 뭐야?", "더 쉽게 설명해 줘",
                    "작가의 일생을 알려 줘", "작가는 어느 나라 사람이야?",
                    "지금 내 상황에 어떻게 적용할까?", "비슷한 뜻의 다른 명언이 있을까?"]
        case .english:
            return ["hi", "who are you", "What is the hidden meaning of this quote?", "Explain it more simply",
                    "Tell me about the author's life", "Where was the author from?",
                    "How can I apply this to my situation?", "Is there another quote with a similar meaning?"]
        case .simplifiedChinese:
            return ["你好", "你是谁", "这句名言隐藏的意思是什么？", "再说得简单一点",
                    "介绍一下作者的一生", "作者是哪国人？",
                    "我现在的情况该怎么运用？", "有意思相近的其他名言吗？"]
        case .traditionalChinese:
            return ["你好", "你是誰", "這句名言隱藏的意思是什麼？", "再說得簡單一點",
                    "介紹一下作者的一生", "作者是哪國人？",
                    "我現在的情況該怎麼運用？", "有意思相近的其他名言嗎？"]
        }
    }

    /// 답 하나의 문제점. 비어 있으면 통과.
    static func evaluate(reply: String, language: AppLanguage, question: String = "", quote: String = "") -> [String] {
        let text = reply.trimmed
        if text.isEmpty { return ["빈 답"] }

        var problems: [String] = []
        if !question.isEmpty,
           ReplyLanguageGuard.normalized(text) == ReplyLanguageGuard.normalized(question) {
            problems.append("질문을 되받음")
        }
        if !quote.isEmpty,
           ReplyLanguageGuard.normalized(text) == ReplyLanguageGuard.normalized(quote) {
            problems.append("명언을 그대로 되풀이함")
        }
        if text.contains("<think") || text.contains("</think") {
            problems.append("생각 구간이 새어 나옴")
        }
        if !ReplyLanguageGuard.matches(text, expected: language) {
            problems.append("앱 언어가 아님")
        }
        if text.count > 700 {
            problems.append("너무 김(\(text.count)자)")
        }
        if hasRepetition(text) {
            problems.append("같은 말 반복")
        }
        return problems
    }

    /// 같은 20글자 조각이 세 번 이상 나오면 되풀이로 본다. (0.6B 가 빠졌던 루프)
    static func hasRepetition(_ text: String) -> Bool {
        let characters = Array(text)
        let window = 20
        guard characters.count >= window * 3 else { return false }
        var seen: [String: Int] = [:]
        for start in 0...(characters.count - window) {
            let piece = String(characters[start..<(start + window)])
            seen[piece, default: 0] += 1
            if seen[piece, default: 0] >= 3 { return true }
        }
        return false
    }

    struct Result: Identifiable, Equatable {
        let id = UUID()
        let prompt: String
        let reply: String
        let seconds: Double
        let problems: [String]
        /// 일상 말이라 모델을 부르지 않고 앱이 정한 답을 냈다.
        var answeredByApp = false

        var passed: Bool { problems.isEmpty }
    }

    /// 복사해서 보낼 보고서. 읽는 사람이 **무엇으로 돌렸는지** 알 수 있게 머리말을 단다.
    static func report(
        model: String,
        language: AppLanguage,
        results: [Result]
    ) -> String {
        var lines = [
            "QuoteDay AI 점검",
            "앱 \(AppVersion.display) · 프롬프트 판 \(QuoteChatPrompt.version)",
            "모델 \(model) · 앱 언어 \(language.rawValue)",
            "통과 \(results.filter(\.passed).count) / \(results.count) (형식만 본다 — 내용이 맞는지는 읽어 봐야 한다)",
            ""
        ]
        for (index, result) in results.enumerated() {
            let mark = result.passed ? "통과" : "문제: " + result.problems.joined(separator: ", ")
            let source = result.answeredByApp ? " · 앱이 답함" : ""
            lines.append("\(index + 1). [\(mark)] (\(String(format: "%.1f", result.seconds))초\(source))")
            lines.append("  질문: \(result.prompt)")
            lines.append("  답: \(result.reply.trimmed)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
