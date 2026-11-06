import XCTest
@testable import QuoteDay

/// "비슷한 명언" 은 앱에 수록된 같은 주제의 명언으로 답한다.
/// (실기기 1.15.6·1.15.7: 두 번 다 지금 명언을 그대로 돌려주었다.)
final class QuoteChatSimilarQuotesTests: XCTestCase {

    func testQuestionMatching() {
        XCTAssertTrue(QuoteChatSimilarQuotes.matches("비슷한 뜻의 다른 명언이 있을까?"))
        XCTAssertTrue(QuoteChatSimilarQuotes.matches("Is there another quote with a similar meaning?"))
        XCTAssertTrue(QuoteChatSimilarQuotes.matches("有意思相近的其他名言吗？"))
        XCTAssertFalse(QuoteChatSimilarQuotes.matches("이 명언의 숨은 뜻이 뭐야?"))
        XCTAssertFalse(QuoteChatSimilarQuotes.matches("지금 내 상황에 어떻게 적용할까?"))
    }

    func testCandidatesSkipTheSameQuoteAndAuthorAndAreStable() {
        let pool = (0..<6).map {
            Quote(slug: "q\($0)", text: "명언 \($0)", authorID: $0 < 2 ? "a" : "b\($0)", category: .relationship)
        }
        let picks = QuoteChatSimilarQuotes.candidates(for: pool[0], in: pool)
        XCTAssertEqual(picks.count, 3)
        XCTAssertFalse(picks.contains { $0.authorID == "a" }, "같은 작가의 명언은 '다른 명언' 이 아니다")
        XCTAssertEqual(picks.map(\.slug), QuoteChatSimilarQuotes.candidates(for: pool[0], in: pool).map(\.slug))
    }

    func testReplyUsesTheLibrary() {
        guard let quote = QuoteLibrary.shared.quotes(in: .relationship).first else {
            return XCTFail("관계 주제 명언이 있어야 한다")
        }
        let context = QuoteChatContext(quote: quote, author: QuoteLibrary.shared.author(for: quote))
        let reply = QuoteChatSimilarQuotes.reply(to: "비슷한 뜻의 다른 명언이 있을까?", language: .korean, context: context) ?? ""
        XCTAssertTrue(reply.hasPrefix("같은 주제("))
        XCTAssertFalse(reply.contains(quote.text), "지금 명언은 다시 보여 주지 않는다")
    }

    func testBiggerModelsNeedMoreFreeMemory() {
        XCTAssertLessThan(LocalQwenModel.small.minimumFreeMemory, LocalQwenModel.large.minimumFreeMemory)
        XCTAssertLessThan(LocalQwenModel.large.minimumFreeMemory, LocalQwenModel.xlarge.minimumFreeMemory)
        XCTAssertGreaterThan(LocalQwenModel.xlarge.minimumFreeMemory, UInt64(LocalQwenModel.xlarge.approximateBytes))
    }
}
