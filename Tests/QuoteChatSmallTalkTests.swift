import XCTest
@testable import QuoteDay

/// 일상 말은 앱이 답하고, 진짜 질문은 **가로채지 않는지** 본다.
///
/// 실기기(1.15.5, Qwen3 1.7B): `안녕` 은 되받아 답을 못 냈고, `야` 는
/// "야는 랠프 월도 에머슨의 친구야.", `넌 누구야` 는 `Quote0.4/1.7/4`.
final class QuoteChatSmallTalkTests: XCTestCase {

    func testCasualInputsFromTheDeviceReportAreCaught() {
        XCTAssertEqual(QuoteChatSmallTalk.classify("안녕"), .greeting)
        XCTAssertEqual(QuoteChatSmallTalk.classify("넌 누구야"), .identity)
        XCTAssertEqual(QuoteChatSmallTalk.classify("야"), .call)
        XCTAssertEqual(QuoteChatSmallTalk.classify("ㅋㅋㅋ"), .noise)
        XCTAssertEqual(QuoteChatSmallTalk.classify("홀롤ㅗ"), .noise)
    }

    func testPunctuationAndSpacingDoNotMatter() {
        XCTAssertEqual(QuoteChatSmallTalk.classify("안녕하세요!!"), .greeting)
        XCTAssertEqual(QuoteChatSmallTalk.classify("너 누구야?"), .identity)
        XCTAssertEqual(QuoteChatSmallTalk.classify("Who are you?"), .identity)
        XCTAssertEqual(QuoteChatSmallTalk.classify("你是谁？"), .identity)
        XCTAssertEqual(QuoteChatSmallTalk.classify("😂😂"), .noise)
    }

    func testRealQuestionsGoToTheModel() {
        let questions = [
            "이 명언의 숨은 뜻이 뭐야?", "작가는 누구야?", "반말하냐", "야 이거 무슨 뜻이야",
            "숨은 뜻 알려줘", "고마워", "What does this mean?", "谢谢", "这句话是什么意思？"
        ]
        for question in questions {
            XCTAssertNil(QuoteChatSmallTalk.classify(question), "\(question) 를 앱이 가로채면 안 된다")
        }
    }

    func testEmptyInputIsNotSmallTalk() {
        XCTAssertNil(QuoteChatSmallTalk.classify("   "))
    }

    func testRepliesAreInTheAppLanguage() {
        for language in AppLanguage.allCases {
            for input in ["안녕", "넌 누구야", "야", "ㅋㅋ"] {
                let reply = QuoteChatSmallTalk.reply(to: input, language: language, context: nil) ?? ""
                XCTAssertFalse(reply.isEmpty)
                XCTAssertTrue(ReplyLanguageGuard.matches(reply, expected: language), "\(language): \(reply)")
            }
        }
    }

    func testIdentityReplyNamesTheAppNotAModel() {
        let reply = QuoteChatSmallTalk.reply(to: "넌 누구야", language: .korean, context: nil) ?? ""
        XCTAssertTrue(reply.contains("QuoteDay"))
        XCTAssertFalse(reply.contains("Qwen"))
    }
}
