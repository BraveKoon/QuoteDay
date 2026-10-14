import XCTest
@testable import QuoteDay

/// 기록 백업이 **무손실**인지 본다.
///
/// 이 앱은 사용자에게 "당신의 기록이 이 앱의 값어치입니다"라고 말하려 한다.
/// 그 말을 하려면 기록을 잃지 않는다는 약속을 먼저 지켜야 한다. 내보내고
/// 다시 들여왔을 때 한 글자라도 달라지면 그 약속은 거짓말이 된다.
final class JournalArchiveTests: XCTestCase {

    private func makeNote(
        id: UUID = UUID(),
        dayKey: String = "2026-10-14",
        slug: String = "seneca-luck",
        text: String = "오늘 면접이 그랬다.",
        mood: String? = nil,
        source: JournalSource = .daily,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> ArchivedNote {
        ArchivedNote(
            id: id,
            dayKey: dayKey,
            quoteSlug: slug,
            quoteText: "행운이란 준비가 기회를 만나는 것이다.",
            authorName: "세네카",
            mood: mood,
            source: source,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - 왕복

    func testExportThenImportKeepsEveryField() throws {
        let original = makeNote(mood: "tired", source: .daily)
        let payload = JournalArchivePayload(appVersion: "1.9", notes: [original])

        let decoded = try JournalArchive.decode(try JournalArchive.encode(payload))

        XCTAssertEqual(decoded.schema, JournalArchivePayload.currentSchema)
        XCTAssertEqual(decoded.appVersion, "1.9")
        XCTAssertEqual(decoded.notes, [original], "내보냈다 들여온 기록이 달라졌습니다.")
    }

    /// 줄바꿈·따옴표·이모지가 든 글도 그대로 돌아와야 한다.
    func testAwkwardTextSurvivesTheRoundTrip() throws {
        let text = "첫 줄\n둘째 줄 \"인용\" 그리고 / 슬래시 😮‍💨 끝"
        let original = makeNote(text: text)
        let payload = JournalArchivePayload(appVersion: "1.9", notes: [original])

        let decoded = try JournalArchive.decode(try JournalArchive.encode(payload))
        XCTAssertEqual(decoded.notes.first?.text, text)
    }

    func testEmptyArchiveRoundTrips() throws {
        let payload = JournalArchivePayload(appVersion: "1.9", notes: [])
        let decoded = try JournalArchive.decode(try JournalArchive.encode(payload))
        XCTAssertTrue(decoded.notes.isEmpty)
    }

    // MARK: - 거절

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try JournalArchive.decode(Data("그냥 글자".utf8))) { error in
            XCTAssertEqual(error as? JournalArchiveError, .notAnArchive)
        }
    }

    /// 다른 JSON 은 우리 파일이 아니다.
    func testUnrelatedJSONIsRejected() {
        let json = Data(#"{"hello":"world"}"#.utf8)
        XCTAssertThrowsError(try JournalArchive.decode(json)) { error in
            XCTAssertEqual(error as? JournalArchiveError, .notAnArchive)
        }
    }

    /// 더 새로운 형식은 **읽지 않는다.** 모르는 필드를 버리고 저장하면
    /// 그 다음 내보내기에서 사용자의 데이터가 조용히 사라진다.
    func testNewerSchemaIsRefusedRatherThanGuessed() throws {
        let future = JournalArchivePayload(
            schema: JournalArchivePayload.currentSchema + 1,
            appVersion: "9.9",
            notes: [makeNote()]
        )
        let data = try JournalArchive.encode(future)
        XCTAssertThrowsError(try JournalArchive.decode(data)) { error in
            XCTAssertEqual(
                error as? JournalArchiveError,
                .tooNew(schema: JournalArchivePayload.currentSchema + 1)
            )
        }
    }

    // MARK: - 합치기

    func testBrandNewNotesAreAdded() {
        let mine = makeNote(id: UUID(), slug: "a")
        let theirs = makeNote(id: UUID(), slug: "b")

        let result = JournalArchive.plan(existing: [mine], incoming: [theirs])
        XCTAssertEqual(result.added.map(\.id), [theirs.id])
        XCTAssertTrue(result.updated.isEmpty)
    }

    /// 같은 글이면 아무 일도 일어나지 않는다.
    func testIdenticalNotesAreLeftAlone() {
        let note = makeNote()
        let result = JournalArchive.plan(existing: [note], incoming: [note])
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.unchanged, 1)
    }

    func testTheLaterEditWins() {
        let id = UUID()
        let old = makeNote(id: id, text: "짧게 적었다", updatedAt: Date(timeIntervalSince1970: 1_000))
        let new = makeNote(id: id, text: "나중에 길게 고쳤다", updatedAt: Date(timeIntervalSince1970: 2_000))

        let result = JournalArchive.plan(existing: [old], incoming: [new])
        XCTAssertEqual(result.updated.first?.text, "나중에 길게 고쳤다")
    }

    /// **가져오기가 기기의 최신 글을 덮지 않는다.** 이쪽이 더 위험하다 —
    /// 오래된 백업을 들여오다 오늘 쓴 글을 잃는 일이 없어야 한다.
    func testAnOlderBackupNeverOverwritesFresherWriting() {
        let id = UUID()
        let onDevice = makeNote(id: id, text: "오늘 고친 글", updatedAt: Date(timeIntervalSince1970: 9_000))
        let inFile = makeNote(id: id, text: "지난달 백업", updatedAt: Date(timeIntervalSince1970: 1_000))

        let result = JournalArchive.plan(existing: [onDevice], incoming: [inFile])
        XCTAssertTrue(result.updated.isEmpty, "오래된 백업이 최신 글을 덮었습니다.")
        XCTAssertEqual(result.unchanged, 1)
    }

    func testMergeSummaryCountsBothKinds() {
        let kept = makeNote(id: UUID())
        let id = UUID()
        let result = JournalArchive.plan(
            existing: [kept, makeNote(id: id, updatedAt: Date(timeIntervalSince1970: 1_000))],
            incoming: [
                makeNote(id: UUID(), slug: "new"),
                makeNote(id: id, updatedAt: Date(timeIntervalSince1970: 2_000)),
                kept
            ]
        )
        XCTAssertEqual(result.added.count, 1)
        XCTAssertEqual(result.updated.count, 1)
        XCTAssertEqual(result.unchanged, 1)
        XCTAssertTrue(result.summary.contains("새 기록 1편"))
        XCTAssertTrue(result.summary.contains("고쳐 쓴 기록 1편"))
    }

    // MARK: - 파일 이름

    func testFileNameCarriesTheDay() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            JournalArchive.fileName(on: date),
            "QuoteDay-기록-\(date.dayKey())"
        )
    }
}
