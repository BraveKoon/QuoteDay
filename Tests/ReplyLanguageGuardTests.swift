import XCTest
@testable import QuoteDay

/// 틀린 언어의 답을 **화면에 내보내기 전에** 막는지 본다.
///
/// 실기기에서 한국어 화면의 모델이 `넌 누구야`, `야` 에 똑같은 영어 문장을 냈다.
final class ReplyLanguageGuardTests: XCTestCase {

    /// 조각을 차례로 넣고 마지막 판정까지 모은다. 거부되면 nil.
    private func run(_ chunks: [String], expected: AppLanguage) -> String? {
        var guardian = ReplyLanguageGuard(expected: expected)
        var shown = ""
        for chunk in chunks {
            switch guardian.feed(chunk) {
            case .hold: break
            case .release(let text): shown += text
            case .reject: return nil
            }
        }
        switch guardian.finish() {
        case .hold: break
        case .release(let text): shown += text
        case .reject: return nil
        }
        return shown
    }

    func testKoreanReplyInKoreanPasses() {
        let reply = "저는 명언을 함께 읽어 주는 도우미예요."
        XCTAssertEqual(run([reply], expected: .korean), reply)
    }

    func testEnglishReplyInKoreanIsRejected() {
        let reply = "I'm a language model developed by the company."
        XCTAssertNil(run([reply], expected: .korean))
    }

    func testRejectionHappensBeforeAnythingIsShown() {
        var guardian = ReplyLanguageGuard(expected: .korean)
        XCTAssertEqual(guardian.feed("I'm a"), .hold)
        XCTAssertEqual(guardian.feed(" language model"), .reject)
    }

    func testSplitChunksAreReleasedTogether() {
        var guardian = ReplyLanguageGuard(expected: .korean)
        XCTAssertEqual(guardian.feed("안녕"), .hold)
        XCTAssertEqual(guardian.feed("하세요 오늘은"), .hold)
        XCTAssertEqual(guardian.feed(" 어떠세요"), .release("안녕하세요 오늘은 어떠세요"))
        XCTAssertEqual(guardian.feed("?"), .release("?"))
    }

    func testShortKoreanReplyIsJudgedAtFinish() {
        XCTAssertEqual(run(["네!"], expected: .korean), "네!")
    }

    func testVeryShortForeignWordIsNotDiscarded() {
        XCTAssertEqual(run(["OK"], expected: .korean), "OK")
    }

    func testShortEnglishReplyInKoreanIsRejectedAtFinish() {
        XCTAssertNil(run(["Hello"], expected: .korean))
    }

    func testKoreanWithEnglishWordsPasses() {
        XCTAssertNotNil(run(["이건 AI 가 만든 설명이 아니라 사람이 쓴 글이에요."], expected: .korean))
    }

    func testEnglishReplyInEnglishPasses() {
        XCTAssertNotNil(run(["I'm a helper that reads quotes with you."], expected: .english))
    }

    func testKoreanReplyInEnglishIsRejected() {
        XCTAssertNil(run(["저는 명언을 함께 읽어 주는 도우미예요."], expected: .english))
    }

    func testChineseReplyPassesForBothScripts() {
        XCTAssertNotNil(run(["我是陪你一起读名言的小助手。"], expected: .simplifiedChinese))
        XCTAssertNotNil(run(["我是陪你一起讀名言的小助手。"], expected: .traditionalChinese))
    }

    func testEnglishReplyInChineseIsRejected() {
        XCTAssertNil(run(["I'm a language model developed by the company."], expected: .simplifiedChinese))
    }

    func testEmptyReplyIsNotRejected() {
        XCTAssertEqual(run([], expected: .korean), "")
    }
}
