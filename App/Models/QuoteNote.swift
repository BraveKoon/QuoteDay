import Foundation
import SwiftData

/// 명언에 대해 사용자가 적어 둔 생각.
///
/// 쓰기와 읽기는 **무료**다. 유료로 파는 것은 이 글을 밖으로 꺼내는 방법
/// (PDF 내보내기)이지, 자기가 쓴 글을 다시 보는 권한이 아니다.
/// 구독이 끊겼다고 사용자의 기록이 잠기면 그건 인질극이다.
@Model
final class QuoteNote {
    @Attribute(.unique) var id: UUID
    /// 대상 명언의 `Quote.slug`. 명언이 사라져도 글은 남는다.
    var quoteSlug: String
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
        quoteTextSnapshot: String,
        authorNameSnapshot: String,
        text: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.quoteSlug = quoteSlug
        self.quoteTextSnapshot = quoteTextSnapshot
        self.authorNameSnapshot = authorNameSnapshot
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension QuoteNote {
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
