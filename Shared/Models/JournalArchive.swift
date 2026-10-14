import Foundation

/// 기록을 어디서 썼는지.
///
/// 글의 값어치를 가르지 않는다. 월간 회고에서 "홈에서 남긴 한 줄"과
/// "명언을 들여다보다 쓴 글"을 구분해 세려고 남겨 둘 뿐이다.
public enum JournalSource: String, Codable, Sendable, CaseIterable {
    /// 홈 화면의 오늘 한 줄.
    case daily
    /// 명언 상세에서 쓴 글.
    case quote
}

/// 내보내기 파일에 담기는 기록 한 편.
///
/// `QuoteNote`(SwiftData)와 따로 두는 이유는 두 가지다. 하나, 저장소 모델이
/// 바뀌어도 파일 형식은 그대로여야 한다 — 어제 내보낸 파일을 내년에도 읽을 수
/// 있어야 백업이라고 부를 수 있다. 둘, 값 타입이라 SwiftData 없이 테스트할 수
/// 있다. 이 저장소에서 가장 중요한 로직은 전부 이렇게 빼 둔다.
public struct ArchivedNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let dayKey: String
    public let quoteSlug: String
    public let quoteText: String
    public let authorName: String
    public let mood: String?
    public let source: JournalSource
    public let text: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        dayKey: String,
        quoteSlug: String,
        quoteText: String,
        authorName: String,
        mood: String? = nil,
        source: JournalSource = .quote,
        text: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.dayKey = dayKey
        self.quoteSlug = quoteSlug
        self.quoteText = quoteText
        self.authorName = authorName
        self.mood = mood
        self.source = source
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 내보내기 파일 한 덩어리.
public struct JournalArchivePayload: Codable, Equatable, Sendable {
    /// 파일 형식 번호. **첫 번째 필드인 데에는 이유가 있다** — 형식이 바뀌어도
    /// 옛 파일을 읽을 수 있으려면, 읽기 전에 몇 번인지부터 알아야 한다.
    public let schema: Int
    public let exportedAt: Date
    public let appVersion: String
    public let notes: [ArchivedNote]

    public static let currentSchema = 1

    public init(
        schema: Int = JournalArchivePayload.currentSchema,
        exportedAt: Date = .now,
        appVersion: String,
        notes: [ArchivedNote]
    ) {
        self.schema = schema
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.notes = notes
    }
}

/// 가져오기가 파일을 거절하는 이유.
public enum JournalArchiveError: Error, Equatable {
    /// JSON 이 아니거나 우리 형식이 아니다.
    case notAnArchive
    /// 이 앱이 읽을 수 없는 더 새로운 형식이다.
    case tooNew(schema: Int)
}

/// 가져오기가 무엇을 했는지.
public struct JournalMergeResult: Equatable, Sendable {
    public let added: [ArchivedNote]
    public let updated: [ArchivedNote]
    public let unchanged: Int

    public var isEmpty: Bool { added.isEmpty && updated.isEmpty }

    /// 사용자에게 보여 줄 한 줄.
    public var summary: String {
        if isEmpty { return "이미 다 가지고 있는 기록이에요." }
        var parts: [String] = []
        if !added.isEmpty { parts.append("새 기록 \(added.count)편") }
        if !updated.isEmpty { parts.append("고쳐 쓴 기록 \(updated.count)편") }
        return parts.joined(separator: " · ") + "을 가져왔어요."
    }
}

public enum JournalArchive {

    // MARK: - 읽고 쓰기

    public static func encode(_ payload: JournalArchivePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // 사람이 열어 볼 수 있어야 한다. 백업 파일이 읽을 수 없는 덩어리면
        // 무엇이 들어 있는지 확인할 방법이 사용자에게 없다.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> JournalArchivePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(JournalArchivePayload.self, from: data) else {
            throw JournalArchiveError.notAnArchive
        }
        guard payload.schema <= JournalArchivePayload.currentSchema else {
            throw JournalArchiveError.tooNew(schema: payload.schema)
        }
        return payload
    }

    // MARK: - 합치기

    /// 가진 것과 가져온 것을 합친다.
    ///
    /// **덮어쓰기 모드는 없다.** 사용자의 글을 지우는 길은 하나(한 편씩 삭제)면
    /// 충분하고, 백업을 되돌리다 멀쩡한 글을 잃는 것이 가장 나쁜 결과다.
    /// 같은 `id` 가 양쪽에 있으면 `updatedAt` 이 늦은 쪽을 남긴다.
    public static func plan(
        existing: [ArchivedNote],
        incoming: [ArchivedNote]
    ) -> JournalMergeResult {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var added: [ArchivedNote] = []
        var updated: [ArchivedNote] = []
        var unchanged = 0

        for note in incoming {
            guard let mine = byID[note.id] else {
                added.append(note)
                continue
            }
            if note.updatedAt > mine.updatedAt {
                updated.append(note)
            } else {
                unchanged += 1
            }
        }
        return JournalMergeResult(added: added, updated: updated, unchanged: unchanged)
    }

    // MARK: - 파일 이름

    /// `QuoteDay-기록-2026-10-14.json`
    public static func fileName(on date: Date = .now, calendar: Calendar = .current) -> String {
        "QuoteDay-기록-\(date.dayKey(calendar: calendar))"
    }
}
