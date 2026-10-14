import Foundation
import SwiftData

/// 명언에 대해 사용자가 적어 둔 생각.
///
/// 쓰기와 읽기는 **무료**다. 유료로 파는 것은 이 글을 보기 좋게 인쇄하는
/// 방법이지, 자기가 쓴 글을 다시 보는 권한이 아니다. 구독이 끊겼다고
/// 사용자의 기록이 잠기면 그건 인질극이다.
///
/// **한 명언에 하나가 아니라, 하루에 하나다.** 명언은 201편뿐이라 같은 문장을
/// 반드시 다시 만난다. 명언으로만 묶으면 반년 뒤에 새로 적은 글이 예전 글을
/// 조용히 덮어쓴다. 기록이 쌓이는 것이 이 앱의 값어치인데, 쌓이는 쪽이 아니라
/// 지워지는 쪽으로 동작하고 있었다.
@Model
final class QuoteNote {
    @Attribute(.unique) var id: UUID
    /// 대상 명언의 `Quote.slug`. 명언이 사라져도 글은 남는다.
    var quoteSlug: String
    /// 적은 날(`yyyy-MM-dd`, 로컬 자정 기준). `quoteSlug` 와 함께 이 글을 가른다.
    ///
    /// `Date` 가 아니라 문자열인 이유는 `RemoteQuote.dayKey` 와 같다 — 시각이
    /// 끼어들면 "같은 날"을 비교할 때마다 달력과 시간대를 끌고 다녀야 한다.
    var dayKey: String = ""
    /// 그날 고른 기분(`QuoteMood.rawValue`). 고르지 않았으면 nil.
    var moodRaw: String?
    /// 어디서 썼는지. `JournalSource` 의 rawValue 를 담는다.
    var sourceRaw: String = JournalSource.quote.rawValue
    /// 목록에서 보여 줄 명언 원문 사본.
    /// slug 로 매번 되찾지 않고 복사해 두는 이유는, 데이터가 갱신되어
    /// 명언이 빠져도 내가 쓴 글의 맥락은 남아야 하기 때문이다.
    var quoteTextSnapshot: String
    var authorNameSnapshot: String
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        quoteSlug: String,
        dayKey: String,
        quoteTextSnapshot: String,
        authorNameSnapshot: String,
        text: String,
        moodRaw: String? = nil,
        source: JournalSource = .quote,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.quoteSlug = quoteSlug
        self.dayKey = dayKey
        self.moodRaw = moodRaw
        self.sourceRaw = source.rawValue
        self.quoteTextSnapshot = quoteTextSnapshot
        self.authorNameSnapshot = authorNameSnapshot
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension QuoteNote {
    var source: JournalSource {
        JournalSource(rawValue: sourceRaw) ?? .quote
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 목록에 보여 줄 한 줄 미리보기.
    var preview: String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.count <= 80 ? flattened : String(flattened.prefix(80)) + "…"
    }
}
