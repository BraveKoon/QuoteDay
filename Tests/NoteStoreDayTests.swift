import SwiftData
import XCTest
@testable import QuoteDay

/// 기록을 가르는 기준이 **명언이 아니라 (날짜, 명언)** 인지 본다.
///
/// 명언은 201편뿐이라 같은 문장을 반드시 다시 만난다. 예전에는 명언 하나에
/// 글 하나였고, 반년 뒤에 새로 적으면 예전 글이 조용히 사라졌다. 기록이
/// 쌓이는 것이 이 앱의 값어치인데 지워지는 쪽으로 동작한 것이다.
@MainActor
final class NoteStoreDayTests: XCTestCase {

    private let service = QuoteService.shared

    private func makeStore() throws -> (NoteStore, ModelContext) {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)
        return (NoteStore(context: context), context)
    }

    private func presentation(at index: Int = 0) -> QuotePresentation {
        service.presentation(for: service.allQuotes[index])
    }

    private func day(_ value: String) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 9
        return Calendar.current.date(from: components) ?? .now
    }

    // MARK: - 하루당 하나

    func testTheSameQuoteOnTwoDaysKeepsBothEntries() throws {
        let (store, _) = try makeStore()
        let quote = presentation()

        store.save(text: "처음 읽었을 때", for: quote, on: day("2026-03-01"))
        store.save(text: "반년 뒤에 다시", for: quote, on: day("2026-09-01"))

        let all = store.allNotes(for: quote.quote.slug)
        XCTAssertEqual(all.count, 2, "같은 명언에 다른 날 쓴 글 하나가 사라졌습니다.")
        XCTAssertEqual(Set(all.map(\.text)), ["처음 읽었을 때", "반년 뒤에 다시"])
    }

    func testWritingTwiceOnOneDayEditsTheSameEntry() throws {
        let (store, _) = try makeStore()
        let quote = presentation()
        let today = day("2026-05-05")

        store.save(text: "처음", for: quote, on: today)
        store.save(text: "고쳐 씀", for: quote, on: today)

        XCTAssertEqual(store.allNotes(for: quote.quote.slug).count, 1)
        XCTAssertEqual(store.note(for: quote.quote.slug, on: today)?.text, "고쳐 씀")
    }

    func testEmptyTextDeletesThatDaysEntryOnly() throws {
        let (store, _) = try makeStore()
        let quote = presentation()

        store.save(text: "남겨 둘 글", for: quote, on: day("2026-03-01"))
        store.save(text: "지울 글", for: quote, on: day("2026-03-02"))
        store.save(text: "   ", for: quote, on: day("2026-03-02"))

        let all = store.allNotes(for: quote.quote.slug)
        XCTAssertEqual(all.map(\.text), ["남겨 둘 글"])
    }

    func testDifferentQuotesOnTheSameDayBothSurvive() throws {
        let (store, _) = try makeStore()
        let today = day("2026-06-10")

        store.save(text: "첫 명언에 대해", for: presentation(at: 0), on: today)
        store.save(text: "둘째 명언에 대해", for: presentation(at: 1), on: today)

        XCTAssertEqual(store.notes(on: today).count, 2)
        XCTAssertEqual(store.recordedDayCount, 1)
    }

    func testRecordedDayCountCountsDaysNotEntries() throws {
        let (store, _) = try makeStore()
        let today = day("2026-06-10")

        store.save(text: "하나", for: presentation(at: 0), on: today)
        store.save(text: "둘", for: presentation(at: 1), on: today)
        store.save(text: "셋", for: presentation(at: 0), on: day("2026-06-11"))

        XCTAssertEqual(store.notes.count, 3)
        XCTAssertEqual(store.recordedDayCount, 2)
    }

    // MARK: - 1.8 에서 올라오기

    /// 예전 노트에는 날짜가 없다. 적은 시각에서 채우되 **한 편도 잃지 않는다.**
    func testOldNotesGetTheirDayFilledInAndNoneAreLost() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)

        let madeOn = day("2026-01-20")
        for index in 0..<3 {
            let note = QuoteNote(
                quoteSlug: "slug-\(index)",
                dayKey: "",
                quoteTextSnapshot: "원문 \(index)",
                authorNameSnapshot: "누군가",
                text: "예전에 쓴 글 \(index)",
                createdAt: madeOn,
                updatedAt: madeOn
            )
            context.insert(note)
        }
        try context.save()

        let store = NoteStore(context: context)

        XCTAssertEqual(store.notes.count, 3, "마이그레이션에서 노트가 사라졌습니다.")
        XCTAssertTrue(
            store.notes.allSatisfy { $0.dayKey == madeOn.dayKey() },
            "날짜가 채워지지 않은 노트가 있습니다."
        )
        XCTAssertEqual(store.recordedDayCount, 1)
    }

    /// 한 번 채운 뒤 다시 열어도 날짜가 흔들리지 않는다.
    func testBackfillIsStableAcrossRelaunches() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)
        let madeOn = day("2026-02-02")

        context.insert(QuoteNote(
            quoteSlug: "slug",
            dayKey: "",
            quoteTextSnapshot: "원문",
            authorNameSnapshot: "누군가",
            text: "글",
            createdAt: madeOn,
            updatedAt: madeOn
        ))
        try context.save()

        _ = NoteStore(context: context)
        let second = NoteStore(context: context)

        XCTAssertEqual(second.notes.count, 1)
        XCTAssertEqual(second.notes.first?.dayKey, madeOn.dayKey())
    }

    // MARK: - 백업 왕복

    /// 내보내기 → 앱을 지우고 다시 설치 → 가져오기. 이것이 실제 사용 경로다.
    func testExportSurvivesAFreshInstall() throws {
        let (store, _) = try makeStore()
        store.save(text: "첫째 날", for: presentation(at: 0), on: day("2026-03-01"))
        store.save(text: "둘째 날", for: presentation(at: 1), on: day("2026-03-02"))

        let data = try JournalArchive.encode(store.exportPayload())

        // 새 기기.
        let (fresh, _) = try makeStore()
        XCTAssertTrue(fresh.isEmpty)

        let result = try fresh.importArchive(data)

        XCTAssertEqual(result.added.count, 2)
        XCTAssertEqual(fresh.notes.count, 2)
        XCTAssertEqual(Set(fresh.notes.map(\.text)), ["첫째 날", "둘째 날"])
        XCTAssertEqual(Set(fresh.notes.map(\.dayKey)), ["2026-03-01", "2026-03-02"])
    }

    /// 두 번 가져와도 두 벌이 되지 않는다.
    func testImportingTwiceDoesNotDuplicate() throws {
        let (store, _) = try makeStore()
        store.save(text: "하나뿐인 글", for: presentation(), on: day("2026-03-01"))
        let data = try JournalArchive.encode(store.exportPayload())

        let (fresh, _) = try makeStore()
        try fresh.importArchive(data)
        let second = try fresh.importArchive(data)

        XCTAssertEqual(fresh.notes.count, 1)
        XCTAssertTrue(second.isEmpty, "같은 파일을 다시 들여왔는데 기록이 늘었습니다.")
    }

    /// 가져오기는 기기에 있던 글을 지우지 않는다.
    func testImportKeepsWhatTheDeviceAlreadyHad() throws {
        let (store, _) = try makeStore()
        store.save(text: "백업에만 있는 글", for: presentation(at: 0), on: day("2026-03-01"))
        let data = try JournalArchive.encode(store.exportPayload())

        let (fresh, _) = try makeStore()
        fresh.save(text: "기기에만 있는 글", for: presentation(at: 1), on: day("2026-04-01"))
        try fresh.importArchive(data)

        XCTAssertEqual(fresh.notes.count, 2)
        XCTAssertTrue(fresh.notes.contains { $0.text == "기기에만 있는 글" })
    }
}
