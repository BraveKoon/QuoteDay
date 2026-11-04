import XCTest
@testable import QuoteDay

/// Qwen3 의 `<think>` 구간이 **화면에 새지 않는지** 본다.
///
/// 사용자가 실제로 본 것: 질문은 한국어인데 화면에 영어 독백이 줄줄 흘렀다.
/// 모델이 어떻게 쓰든(한 조각에 통째로, 표시가 두 조각에 걸쳐서, 끝내 닫지 않고)
/// 보이는 것은 답뿐이어야 한다.
final class QwenThinkingFilterTests: XCTestCase {

    /// 조각을 차례로 넣고 보이는 글을 이어 붙인다. (`finish` 까지)
    private func run(_ chunks: [String]) -> String {
        var filter = QwenThinkingFilter()
        var shown = ""
        for chunk in chunks { shown += filter.feed(chunk) }
        shown += filter.finish()
        return shown
    }

    func testPlainAnswerPassesThroughUntouched() {
        XCTAssertEqual(run(["핵심은 ", "이렇다."]), "핵심은 이렇다.")
    }

    func testThinkingBlockInOneChunkIsRemoved() {
        XCTAssertEqual(run(["<think>Okay, the user asks...</think>답은 이렇다."]), "답은 이렇다.")
    }

    /// `/no_think` 가 먹었을 때 템플릿이 남기는 빈 생각 구간과 그 뒤의 빈 줄.
    func testEmptyThinkingBlockAndItsBlankLinesAreRemoved() {
        XCTAssertEqual(run(["<think>\n\n</think>\n\n답은 이렇다."]), "답은 이렇다.")
    }

    /// 조각은 아무 데서나 끊긴다. 표시가 두 조각에 걸쳐 와도 새지 않아야 한다.
    func testTagsSplitAcrossChunksDoNotLeak() {
        let chunks = ["<thi", "nk>Wait, maybe", " the hidden</th", "ink>\n\n그", "래서 이렇다."]
        XCTAssertEqual(run(chunks), "그래서 이렇다.")
    }

    func testOneCharacterAtATimeStillWorks() {
        let text = "<think>reasoning here</think>답이다"
        XCTAssertEqual(run(text.map { String($0) }), "답이다")
    }

    /// 토큰 한도에 걸려 생각 도중에 끝나면 보여 줄 것이 없다. 독백을 내보내지 않는다.
    func testUnclosedThinkingShowsNothing() {
        XCTAssertEqual(run(["<think>Hmm, ", "let me think about this..."]), "")
    }

    func testTextBeforeAThinkingBlockIsKept() {
        XCTAssertEqual(run(["먼저 말한다. <think>속으로 생각</think>이어 말한다."]), "먼저 말한다. 이어 말한다.")
    }

    /// 표시처럼 보이지만 표시가 아닌 글은 끝내 나와야 한다. (`<` 하나를 쥐고 있다가 잃으면 안 된다.)
    func testLookalikeTextIsNotSwallowed() {
        XCTAssertEqual(run(["3 ", "<", " 5 이므로"]), "3 < 5 이므로")
        XCTAssertEqual(run(["a <thin"]), "a <thin")
    }

    /// 맨 앞의 공백만 버린다. 답 중간의 줄바꿈은 문단 구분이라 그대로 둔다.
    func testOnlyLeadingWhitespaceIsTrimmed() {
        XCTAssertEqual(run(["\n\n첫 문단.\n\n둘째 문단."]), "첫 문단.\n\n둘째 문단.")
    }

    func testTwoThinkingBlocksAreBothRemoved() {
        XCTAssertEqual(run(["<think>a</think>하나 <think>b</think>둘"]), "하나 둘")
    }
}
