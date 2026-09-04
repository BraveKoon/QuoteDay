import Foundation
import SwiftData

/// 필사 노트의 CRUD.
///
/// `ScheduleStore` 와 같은 규칙을 따른다 — 뷰는 SwiftData 컨텍스트를 직접 만지지 않고
/// 이 타입만 쓴다. 저장 실패는 던지지 않고 `lastErrorMessage` 로 알린다.
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [QuoteNote] = []
    var lastErrorMessage: String?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
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

    /// 이 명언에 달린 노트. 명언 하나에 노트 하나를 원칙으로 한다.
    func note(for quoteSlug: String) -> QuoteNote? {
        notes.first { $0.quoteSlug == quoteSlug }
    }

    var isEmpty: Bool { notes.isEmpty }

    // MARK: - 쓰기

    /// 노트를 저장한다. 본문이 비면 노트를 지운다 — 빈 껍데기를 남기지 않는다.
    func save(text: String, for presentation: QuotePresentation) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = presentation.quote.slug

        if let existing = note(for: slug) {
            if trimmed.isEmpty {
                delete(existing)
                return
            }
            existing.text = trimmed
            existing.quoteTextSnapshot = presentation.quote.text
            existing.authorNameSnapshot = presentation.author.displayName
            existing.updatedAt = .now
        } else {
            guard !trimmed.isEmpty else { return }
            context.insert(QuoteNote(
                quoteSlug: slug,
                quoteTextSnapshot: presentation.quote.text,
                authorNameSnapshot: presentation.author.displayName,
                text: trimmed
            ))
        }
        persist()
    }

    func delete(_ note: QuoteNote) {
        context.delete(note)
        persist()
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
