import Foundation
import SwiftData

/// 기록(필사 노트)의 CRUD 와 백업.
///
/// `ScheduleStore` 와 같은 규칙을 따른다 — 뷰는 SwiftData 컨텍스트를 직접 만지지 않고
/// 이 타입만 쓴다. 저장 실패는 던지지 않고 `lastErrorMessage` 로 알린다.
///
/// 글을 가르는 기준은 **명언 하나가 아니라 (날짜, 명언) 한 쌍**이다.
/// 명언은 201편뿐이라 같은 문장을 반드시 다시 만나는데, 명언으로만 묶으면
/// 반년 뒤에 적은 글이 예전 글을 조용히 덮어썼다.
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [QuoteNote] = []
    var lastErrorMessage: String?

    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
        backfillDayKeys()
        reload()
    }

    // MARK: - 조회

    func reload() {
        let descriptor = FetchDescriptor<QuoteNote>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            notes = try context.fetch(descriptor)
        } catch {
            notes = []
            lastErrorMessage = "노트를 불러오지 못했습니다."
            AppLog.notes.error("fetch 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 그날 그 명언에 쓴 글. 쓰기가 덮어쓸 대상이기도 하다.
    func note(for quoteSlug: String, on date: Date = .now) -> QuoteNote? {
        let day = date.dayKey(calendar: calendar)
        return notes.first { $0.quoteSlug == quoteSlug && $0.dayKey == day }
    }

    /// 이 명언에 남긴 글 전부. 최근에 고친 순.
    ///
    /// 명언 상세가 "예전에 남긴 글이 있어요"를 보여 줄 때 쓴다.
    func allNotes(for quoteSlug: String) -> [QuoteNote] {
        notes.filter { $0.quoteSlug == quoteSlug }
    }

    /// 그날 남긴 글 전부.
    func notes(on date: Date) -> [QuoteNote] {
        let day = date.dayKey(calendar: calendar)
        return notes.filter { $0.dayKey == day }
    }

    /// 글을 남긴 날이 모두 며칠인지.
    var recordedDayCount: Int {
        Set(notes.map(\.dayKey)).count
    }

    var isEmpty: Bool { notes.isEmpty }

    // MARK: - 쓰기

    /// 노트를 저장한다. 본문이 비면 노트를 지운다 — 빈 껍데기를 남기지 않는다.
    func save(
        text: String,
        for presentation: QuotePresentation,
        on date: Date = .now,
        source: JournalSource = .quote,
        mood: String? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = presentation.quote.slug

        if let existing = note(for: slug, on: date) {
            if trimmed.isEmpty {
                delete(existing)
                return
            }
            existing.text = trimmed
            existing.quoteTextSnapshot = presentation.quote.text
            existing.authorNameSnapshot = presentation.author.displayName
            if let mood { existing.moodRaw = mood }
            existing.updatedAt = .now
        } else {
            guard !trimmed.isEmpty else { return }
            context.insert(QuoteNote(
                quoteSlug: slug,
                dayKey: date.dayKey(calendar: calendar),
                quoteTextSnapshot: presentation.quote.text,
                authorNameSnapshot: presentation.author.displayName,
                text: trimmed,
                moodRaw: mood,
                source: source
            ))
        }
        persist()
    }

    func delete(_ note: QuoteNote) {
        context.delete(note)
        persist()
    }

    // MARK: - 백업

    /// 지금 가진 기록 전부를 내보낼 꾸러미로.
    func exportPayload(appVersion: String = AppVersion.marketing) -> JournalArchivePayload {
        JournalArchivePayload(
            appVersion: appVersion,
            notes: notes.map(\.archived).sorted { $0.createdAt < $1.createdAt }
        )
    }

    /// 내보낸 파일을 다시 들여온다.
    ///
    /// 가진 글은 지우지 않는다. 같은 `id` 가 양쪽에 있으면 `updatedAt` 이 늦은
    /// 쪽만 덮어쓴다.
    @discardableResult
    func importArchive(_ data: Data) throws -> JournalMergeResult {
        let payload = try JournalArchive.decode(data)
        let result = JournalArchive.plan(
            existing: notes.map(\.archived),
            incoming: payload.notes
        )

        let byID = Dictionary(notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for incoming in result.added {
            context.insert(QuoteNote.make(from: incoming))
        }
        for incoming in result.updated {
            byID[incoming.id]?.apply(incoming)
        }
        persist()
        return result
    }

    // MARK: - 마이그레이션

    /// 1.8 까지 쓰던 노트에는 `dayKey` 가 없다. 적은 날짜에서 채운다.
    ///
    /// 한 번만 돌면 되지만 플래그를 두지 않는다 — 비어 있는 것만 채우므로
    /// 여러 번 돌아도 같은 결과이고, 플래그가 틀어졌을 때가 더 위험하다.
    private func backfillDayKeys() {
        let descriptor = FetchDescriptor<QuoteNote>(
            // `isEmpty` 대신 비교를 쓴다. 술어는 SQL 로 번역되는데, 프로퍼티
            // 메서드는 번역되지 않는 경우가 있다.
            predicate: #Predicate { $0.dayKey == "" }
        )
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for note in stale {
            note.dayKey = note.createdAt.dayKey(calendar: calendar)
        }
        do {
            try context.save()
            AppLog.notes.debug("노트 \(stale.count)편에 날짜를 채웠습니다.")
        } catch {
            AppLog.notes.error("날짜 채우기 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            lastErrorMessage = "노트를 저장하지 못했습니다."
            AppLog.notes.error("save 실패: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }
}

// MARK: - 저장소 모델 ↔ 파일 형식

extension QuoteNote {
    var archived: ArchivedNote {
        ArchivedNote(
            id: id,
            dayKey: dayKey,
            quoteSlug: quoteSlug,
            quoteText: quoteTextSnapshot,
            authorName: authorNameSnapshot,
            mood: moodRaw,
            source: source,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// 편의 이니셜라이저 대신 팩토리를 쓴다. `@Model` 매크로가 만드는
    /// 이니셜라이저와 엮이지 않는 쪽이 안전하다.
    static func make(from archived: ArchivedNote) -> QuoteNote {
        QuoteNote(
            id: archived.id,
            quoteSlug: archived.quoteSlug,
            dayKey: archived.dayKey,
            quoteTextSnapshot: archived.quoteText,
            authorNameSnapshot: archived.authorName,
            text: archived.text,
            moodRaw: archived.mood,
            source: archived.source,
            createdAt: archived.createdAt,
            updatedAt: archived.updatedAt
        )
    }

    func apply(_ archived: ArchivedNote) {
        dayKey = archived.dayKey
        quoteSlug = archived.quoteSlug
        quoteTextSnapshot = archived.quoteText
        authorNameSnapshot = archived.authorName
        moodRaw = archived.mood
        sourceRaw = archived.source.rawValue
        text = archived.text
        createdAt = archived.createdAt
        updatedAt = archived.updatedAt
    }
}
