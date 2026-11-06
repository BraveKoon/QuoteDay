import XCTest
@testable import QuoteDay

/// 답 머리에 옮겨 적은 명언을 떼는지, 그 밖의 글은 그대로 두는지 본다.
///
/// 실기기(1.15.7, Qwen3 1.7B): 답이 매번 `친구야말로 자연의 걸작이라 할 만하다.` 로 시작했다.
final class QuotePrefixFilterTests: XCTestCase {
    private let quote = "친구야말로 자연의 걸작이라 할 만하다."

    private func run(_ chunks: [String]) -> String {
        var filter = QuotePrefixFilter(quote: quote)
        var shown = ""
        for chunk in chunks { shown += filter.feed(chunk) }
        shown += filter.finish()
        return shown
    }

    func testLeadingQuoteIsDroppedFromTheDeviceReply() {
        let reply = run(["친구야말로 자연의 ", "걸작이라 할 만하다.  \n", "이 명언의 숨은 뜻은 친구가 소중하다는 것입니다."])
        XCTAssertEqual(reply, "이 명언의 숨은 뜻은 친구가 소중하다는 것입니다.")
    }

    func testQuotedQuoteIsDroppedToo() {
        XCTAssertEqual(run(["\u{201C}친구야말로 자연의 걸작이라 할 만하다\u{201D} — 이 말은 우정을 말해요."]),
                       "이 말은 우정을 말해요.")
    }

    func testReplyThatOnlyStartsLikeTheQuoteIsKept() {
        XCTAssertEqual(run(["친구는 ", "소중한 존재예요."]), "친구는 소중한 존재예요.")
    }

    func testOrdinaryReplyPassesThrough() {
        XCTAssertEqual(run(["에머슨은 ", "우정을 ", "자연에 빗댔어요."]), "에머슨은 우정을 자연에 빗댔어요.")
    }

    func testQuoteOnlyReplyIsLeftForTheGuard() {
        XCTAssertEqual(run([quote]), quote, "명언만 적은 답은 가드가 되받기로 거른다")
    }
}
