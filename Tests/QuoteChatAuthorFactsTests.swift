import XCTest
@testable import QuoteDay

/// 작가 사실은 앱 자료로 답하고, 해석을 묻는 질문은 **가로채지 않는지** 본다.
///
/// 실기기(1.15.6, Qwen3 1.7B): `작가는 어느 나라 사람이야?` → "한국 사람이야." (자료: 미국),
/// `작가의 일생을 알려 줘` → 태어난 날·곳을 지어냄.
final class QuoteChatAuthorFactsTests: XCTestCase {

    private var emerson: Author {
        Author(
            id: "emerson-test", name: "Ralph Waldo Emerson", koreanName: "랠프 월도 에머슨",
            birthYear: 1803, deathYear: 1882,
            occupation: "사상가 · 시인", nationality: "미국",
            biography: "미국 초월주의를 이끈 사상가로, 자기 신뢰와 자연 속의 삶을 강조했다.",
            achievements: ["《자기신뢰》", "《자연론》"]
        )
    }

    private var context: QuoteChatContext {
        QuoteChatContext(
            quote: Quote(slug: "emerson-friend-test", text: "친구야말로 자연의 걸작이라 할 만하다.",
                         authorID: "emerson-test", category: .relationship),
            author: emerson
        )
    }

    func testDeviceReportQuestionsAreAnsweredFromAppData() {
        XCTAssertEqual(QuoteChatAuthorFacts.classify("작가는 어느 나라 사람이야?"), .nationality)
        XCTAssertEqual(QuoteChatAuthorFacts.classify("작가의 일생을 알려 줘"), .profile)

        let nationality = QuoteChatAuthorFacts.reply(to: "작가는 어느 나라 사람이야?", language: .korean, context: context)
        XCTAssertEqual(nationality, "랠프 월도 에머슨은 미국 사람이에요. 사상가 · 시인으로 알려져 있어요.")

        let profile = QuoteChatAuthorFacts.reply(to: "작가의 일생을 알려 줘", language: .korean, context: context) ?? ""
        XCTAssertTrue(profile.contains("1803–1882"))
        XCTAssertTrue(profile.contains("미국 초월주의를 이끈 사상가"))
        XCTAssertTrue(profile.contains("《자기신뢰》"))
    }

    func testLifespanAndOccupation() {
        XCTAssertEqual(QuoteChatAuthorFacts.reply(to: "작가는 언제 태어났어?", language: .korean, context: context),
                       "랠프 월도 에머슨은 1803년에 태어나 1882년에 세상을 떠났어요.")
        XCTAssertEqual(QuoteChatAuthorFacts.reply(to: "작가 직업이 뭐야?", language: .korean, context: context),
                       "랠프 월도 에머슨은 미국의 사상가 · 시인이에요.")
    }

    func testAuthorNameCountsAsAReference() {
        XCTAssertEqual(QuoteChatAuthorFacts.classify("에머슨은 어느 나라 사람이야?", author: emerson), .nationality)
        XCTAssertNil(QuoteChatAuthorFacts.classify("에머슨은 어느 나라 사람이야?"), "작가를 모르면 누구 이야기인지 모른다")
    }

    func testInterpretiveQuestionsGoToTheModel() {
        let questions = [
            "작가의 삶이 이 명언에 어떻게 드러나?", "작가는 왜 이런 말을 했을까?", "이 명언의 숨은 뜻이 뭐야?",
            "어느 나라 사람이야?", "지금 내 상황에 어떻게 적용할까?", "비슷한 뜻의 다른 명언이 있을까?",
            "How did the author's life shape this quote?", "作者为什么这么说？"
        ]
        for question in questions {
            XCTAssertNil(QuoteChatAuthorFacts.classify(question, author: emerson), "\(question) 는 모델이 답해야 한다")
        }
    }

    func testOtherLanguagesUseTranslatedFieldsOnly() {
        // 이 테스트용 인물은 번역표에 없다. 한국어 원문을 영어 화면에 내보내지 않고 모델에게 넘긴다.
        XCTAssertNil(QuoteChatAuthorFacts.reply(to: "Where was the author from?", language: .english, context: context))
    }

    func testEnglishAndChineseClassify() {
        XCTAssertEqual(QuoteChatAuthorFacts.classify("Where was the author from?"), .nationality)
        XCTAssertEqual(QuoteChatAuthorFacts.classify("Tell me about the author's life"), .profile)
        XCTAssertEqual(QuoteChatAuthorFacts.classify("作者是哪国人？"), .nationality)
        XCTAssertEqual(QuoteChatAuthorFacts.classify("介紹一下作者的一生"), .profile)
    }

    func testKoreanParticles() {
        XCTAssertEqual(QuoteChatAuthorFacts.josa("에머슨", "은", "는"), "은")
        XCTAssertEqual(QuoteChatAuthorFacts.josa("소로", "은", "는"), "는")
        XCTAssertEqual(QuoteChatAuthorFacts.josaRo("시인"), "으로")
        XCTAssertEqual(QuoteChatAuthorFacts.josaRo("작가"), "로")
        XCTAssertEqual(QuoteChatAuthorFacts.josaRo("철학"), "으로")
        XCTAssertEqual(QuoteChatAuthorFacts.josaRo("소설"), "로")
    }

    // MARK: - 이어 받는 질문에만 앞 질문을 붙인다 (1.15.6 점검 7번)

    func testFollowUpDetection() {
        XCTAssertTrue(LocalQwenChatTransport.isFollowUp("더 쉽게 설명해 줘"))
        XCTAssertTrue(LocalQwenChatTransport.isFollowUp("Explain it more simply"))
        XCTAssertTrue(LocalQwenChatTransport.isFollowUp("再说得简单一点"))
        XCTAssertFalse(LocalQwenChatTransport.isFollowUp("지금 내 상황에 어떻게 적용할까?"))
        XCTAssertFalse(LocalQwenChatTransport.isFollowUp("비슷한 뜻의 다른 명언이 있을까?"))
        XCTAssertFalse(LocalQwenChatTransport.isFollowUp("How can I apply this to my situation?"))
    }
}
