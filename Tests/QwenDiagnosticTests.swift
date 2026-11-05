import XCTest
@testable import QuoteDay

/// 기기 점검 화면이 쓰는 판정과 질문 목록. 판정이 틀리면 점검 결과를 믿을 수 없다.
final class QwenDiagnosticTests: XCTestCase {

    func testEveryLanguageHasEightPrompts() {
        for language in AppLanguage.allCases {
            XCTAssertEqual(QwenDiagnostic.prompts(language: language).count, 8, "\(language)")
        }
    }

    func testGoodKoreanReplyPasses() {
        XCTAssertTrue(QwenDiagnostic.evaluate(reply: "저는 명언을 함께 읽는 도우미예요.", language: .korean).isEmpty)
    }

    func testEmptyReplyFails() {
        XCTAssertFalse(QwenDiagnostic.evaluate(reply: "  \n", language: .korean).isEmpty)
    }

    func testWrongLanguageFails() {
        XCTAssertFalse(QwenDiagnostic.evaluate(reply: "I'm a language model developed by the company.",
                                               language: .korean).isEmpty)
    }

    func testLeakedThinkingFails() {
        XCTAssertFalse(QwenDiagnostic.evaluate(reply: "<think>음…</think> 안녕하세요, 반가워요.",
                                               language: .korean).isEmpty)
    }

    func testTooLongFails() {
        let long = String(repeating: "가나다라마바사 ", count: 120)
        XCTAssertTrue(QwenDiagnostic.evaluate(reply: long, language: .korean).contains { $0.hasPrefix("너무 김") })
    }

    func testRepetitionDetected() {
        let loop = String(repeating: "같은 말을 계속 되풀이합니다 ", count: 6)
        XCTAssertTrue(QwenDiagnostic.hasRepetition(loop))
        XCTAssertFalse(QwenDiagnostic.hasRepetition("짧은 답은 반복이 아니다."))
    }
}
