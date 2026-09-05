import Foundation

/// 명언이 나온 상황과 맥락. Quote Plus 전용 콘텐츠다.
///
/// `Quote` 안에 넣지 않고 slug 로 참조하는 별도 타입으로 둔 이유:
/// - 명언 130편 전부에 배경이 있는 것은 아니다. 확인된 것만 채워 넣는다.
/// - 무료 화면(위젯·알림)이 읽을 일이 없어 번들 파싱 비용을 나눌 수 있다.
public struct BehindStory: Identifiable, Hashable, Codable, Sendable {
    /// 대상 명언의 `Quote.slug`.
    public let quoteSlug: String
    /// 언제·어디서 나온 말인지 한 줄 요약 (예: "1940년 6월, 영국 하원").
    public let occasion: String
    /// 그 말이 나온 상황 설명 2~4문장.
    public let context: String
    /// 지금 우리에게 어떤 의미인지 (선택).
    public let takeaway: String?
    /// 확인에 쓴 출처. 표기용이며 비워 두지 않는 것을 원칙으로 한다.
    public let source: String

    public init(
        quoteSlug: String,
        occasion: String,
        context: String,
        takeaway: String? = nil,
        source: String
    ) {
        self.quoteSlug = quoteSlug
        self.occasion = occasion
        self.context = context
        self.takeaway = takeaway
        self.source = source
    }

    public var id: String { quoteSlug }
}
