import XCTest
@testable import QuoteDay

/// 동기화가 **글을 잃지 않는지** 본다.
///
/// CloudKit 은 시뮬레이터에서도 CI 에서도 돌아가지 않는다. 그래서 틀리면 글이
/// 사라지는 판단만 `JournalSync` 로 끌어내 두었고, 여기서는 그 판단만 본다.
/// 레코드를 옮겨 담는 쪽은 기기에서 확인해야 한다.
final class JournalSyncPlanTests: XCTestCase {

    // 두 기기가 같은 답을 내는지 보려면 id 가 고정되어 있어야 한다.
    private let idA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!
    private let idB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!
    private let idC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000000")!

    private let morning = Date(timeIntervalSince1970: 1_800_000_000)
    private let evening = Date(timeIntervalSince1970: 1_800_030_000)
    private let night = Date(timeIntervalSince1970: 1_800_060_000)

    private func note(
        _ id: UUID,
        day: String = "2026-10-14",
        slug: String = "seneca-luck",
        text: String = "오늘은 그런 날이었다.",
        mood: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> ArchivedNote {
        ArchivedNote(
            id: id,
            dayKey: day,
            quoteSlug: slug,
            quoteText: "행운이란 준비가 기회를 만나는 것이다.",
            authorName: "세네카",
            mood: mood,
            source: .daily,
            text: text,
            createdAt: createdAt ?? updatedAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - 아무 일도 없을 때

    func testNothingToDoWhenBothSidesAreEmpty() {
        XCTAssertTrue(JournalSync.plan(local: [], remote: []).isEmpty)
    }

    func testIdenticalNotesMakeNoWork() {
        let mine = note(idA, updatedAt: morning)
        let plan = JournalSync.plan(local: [mine], remote: [mine])
        XCTAssertTrue(plan.isEmpty, "똑같은 글을 두고 쓸데없이 왕복합니다.")
    }

    // MARK: - 첫 동기화

    func testFirstSyncUploadsEverythingOnTheDevice() {
        let mine = [
            note(idA, day: "2026-10-14", updatedAt: morning),
            note(idB, day: "2026-10-15", updatedAt: evening)
        ]
        let plan = JournalSync.plan(local: mine, remote: [])

        XCTAssertEqual(plan.upload.map(\.id), [idA, idB])
        XCTAssertTrue(plan.upsertLocally.isEmpty)
        XCTAssertTrue(plan.deleteLocally.isEmpty)
        XCTAssertTrue(plan.deleteRemotely.isEmpty)
    }

    func testANewDeviceTakesEverythingFromTheCloud() {
        let theirs = [
            note(idA, day: "2026-10-14", updatedAt: morning),
            note(idB, day: "2026-10-15", updatedAt: evening)
        ]
        let plan = JournalSync.plan(local: [], remote: theirs)

        XCTAssertEqual(plan.upsertLocally.map(\.id), [idA, idB])
        XCTAssertTrue(plan.upload.isEmpty)
    }

    // MARK: - 같은 글이 양쪽에서 바뀌었을 때

    func testTheLaterEditWinsWhenItCameFromTheCloud() {
        let mine = note(idA, text: "아침에 쓴 글", updatedAt: morning)
        let theirs = note(idA, text: "저녁에 고친 글", updatedAt: evening)

        let plan = JournalSync.plan(local: [mine], remote: [theirs])

        XCTAssertEqual(plan.upsertLocally.first?.text, "저녁에 고친 글")
        XCTAssertTrue(plan.upload.isEmpty, "진 쪽을 도로 올리고 있습니다.")
    }

    func testTheLaterEditWinsWhenItIsMine() {
        let mine = note(idA, text: "저녁에 고친 글", updatedAt: evening)
        let theirs = note(idA, text: "아침에 쓴 글", updatedAt: morning)

        let plan = JournalSync.plan(local: [mine], remote: [theirs])

        XCTAssertEqual(plan.upload.first?.text, "저녁에 고친 글")
        XCTAssertTrue(plan.upsertLocally.isEmpty, "내 최신 글을 옛 글로 덮어씁니다.")
    }

    // MARK: - 삭제

    func testARemoteDeletionRemovesTheNoteHere() {
        let mine = note(idA, updatedAt: morning)
        let plan = JournalSync.plan(local: [mine], remote: [], remotelyDeleted: [idA])

        XCTAssertEqual(plan.deleteLocally, [idA])
        XCTAssertTrue(plan.upload.isEmpty, "지워진 글을 도로 올리고 있습니다.")
    }

    /// 같은 묶음에 수정과 삭제가 함께 와도 글이 되살아나면 안 된다.
    func testADeletionBeatsAnEditInTheSameBatch() {
        let theirs = note(idA, updatedAt: evening)
        let plan = JournalSync.plan(
            local: [note(idA, updatedAt: morning)],
            remote: [theirs],
            remotelyDeleted: [idA]
        )

        XCTAssertEqual(plan.deleteLocally, [idA])
        XCTAssertTrue(plan.upsertLocally.isEmpty)
    }

    /// 비행기 모드에서 지우고, 올리기 전에 받아 오는 경우.
    ///
    /// 이걸 놓치면 **지운 글이 그대로 되살아난다.** 사용자가 지운 글이 며칠 뒤
    /// 혼자 돌아오는 것만큼 나쁜 동작은 드물다.
    func testANoteDeletedOfflineDoesNotComeBack() {
        let stillOnTheServer = note(idA, updatedAt: morning)
        let plan = JournalSync.plan(
            local: [],
            remote: [stillOnTheServer],
            pendingLocalDeletions: [idA]
        )

        XCTAssertTrue(plan.upsertLocally.isEmpty, "지운 글이 되살아났습니다.")
        XCTAssertEqual(plan.deleteRemotely, [idA], "지우다 만 글이 서버에 남습니다.")
    }

    // MARK: - 중복 (같은 날, 같은 명언, 다른 id)

    func testTwoDevicesThatWroteOnTheSameDayKeepBothTexts() {
        let mine = note(idA, text: "아침에 쓴 글", updatedAt: morning)
        let theirs = note(idB, text: "저녁에 쓴 글", updatedAt: evening)

        let plan = JournalSync.plan(local: [mine], remote: [theirs])

        XCTAssertEqual(plan.upsertLocally.count, 1, "같은 날 같은 명언에 글이 둘 남았습니다.")
        XCTAssertEqual(plan.upsertLocally.first?.id, idB, "늦게 고친 쪽이 이겨야 합니다.")
        XCTAssertEqual(
            plan.upsertLocally.first?.text,
            "저녁에 쓴 글" + JournalSync.mergeSeparator + "아침에 쓴 글"
        )
        XCTAssertEqual(plan.deleteLocally, [idA])
        XCTAssertEqual(plan.deleteRemotely, [idA])
        XCTAssertEqual(plan.upload.map(\.id), [idB], "합친 글을 올리지 않으면 저쪽은 모릅니다.")
    }

    /// 두 기기가 **따로 계산해도 같은 글**이 나와야 한다.
    ///
    /// 여기가 어긋나면 두 기기가 서로의 결과를 번갈아 덮어쓰며 본문이 계속
    /// 바뀐다. 설계에서 가장 중요한 성질이다.
    func testBothDevicesComputeTheSameMerge() {
        let a = note(idA, text: "아침에 쓴 글", updatedAt: morning)
        let b = note(idB, text: "저녁에 쓴 글", updatedAt: evening)

        let fromA = JournalSync.plan(local: [a], remote: [b])
        let fromB = JournalSync.plan(local: [b], remote: [a])

        XCTAssertEqual(fromA.upsertLocally, fromB.upsertLocally)
        XCTAssertEqual(fromA.upload, fromB.upload)
        XCTAssertEqual(fromA.deleteRemotely, fromB.deleteRemotely)
    }

    func testThreeWayDuplicatesAllEndUpInOneNote() {
        let a = note(idA, text: "첫째", updatedAt: morning)
        let b = note(idB, text: "둘째", updatedAt: evening)
        let c = note(idC, text: "셋째", updatedAt: night)

        let plan = JournalSync.plan(local: [a], remote: [b, c])

        XCTAssertEqual(plan.upsertLocally.count, 1)
        let text = plan.upsertLocally.first?.text ?? ""
        XCTAssertTrue(text.contains("첫째"))
        XCTAssertTrue(text.contains("둘째"))
        XCTAssertTrue(text.contains("셋째"))
        XCTAssertEqual(plan.deleteRemotely, [idA, idB], "이긴 쪽만 남아야 합니다.")
    }

    /// 시각이 같으면 `id` 로 가른다. 아무렇게나 고르면 두 기기가 다른 답을 낸다.
    func testATieIsBrokenByIdSoBothDevicesAgree() {
        let a = note(idA, text: "A 가 쓴 글", updatedAt: morning)
        let b = note(idB, text: "B 가 쓴 글", updatedAt: morning)

        let plan = JournalSync.plan(local: [b], remote: [a])

        XCTAssertEqual(plan.upsertLocally.first?.id, idA, "id 가 작은 쪽이 이겨야 합니다.")
        XCTAssertEqual(plan.upsertLocally.first?.text, "A 가 쓴 글" + JournalSync.mergeSeparator + "B 가 쓴 글")
    }

    /// 합치기를 또 돌려도 본문이 자라면 안 된다.
    func testMergingTwiceDoesNotDuplicateTheText() throws {
        let a = note(idA, text: "아침에 쓴 글", updatedAt: morning)
        let b = note(idB, text: "저녁에 쓴 글", updatedAt: evening)

        let once = JournalSync.plan(local: [a], remote: [b])
        let merged = try XCTUnwrap(once.upsertLocally.first)

        // 합쳐진 글만 남은 기기가, 아직 합치지 않은 기기에서 옛 글을 또 받는다.
        let twice = JournalSync.plan(local: [merged], remote: [a])

        XCTAssertEqual(twice.upsertLocally.first?.text, merged.text, "본문이 자랐습니다.")
    }

    func testTheEarliestCreatedAtSurvivesTheMerge() {
        let a = note(idA, text: "먼저", createdAt: morning, updatedAt: morning)
        let b = note(idB, text: "나중", createdAt: evening, updatedAt: night)

        let plan = JournalSync.plan(local: [a], remote: [b])

        XCTAssertEqual(plan.upsertLocally.first?.createdAt, morning, "처음 쓴 시각이 사라졌습니다.")
    }

    func testTheLoserMoodIsKeptWhenTheWinnerHasNone() {
        let a = note(idA, text: "기분을 골랐다", mood: "tired", updatedAt: morning)
        let b = note(idB, text: "안 골랐다", mood: nil, updatedAt: evening)

        let plan = JournalSync.plan(local: [a], remote: [b])

        XCTAssertEqual(plan.upsertLocally.first?.mood, "tired")
    }

    // MARK: - 합치면 안 되는 것

    func testDifferentDaysAreNeverMerged() {
        let a = note(idA, day: "2026-10-14", updatedAt: morning)
        let b = note(idB, day: "2026-10-15", updatedAt: evening)

        let plan = JournalSync.plan(local: [a], remote: [b])

        XCTAssertEqual(plan.upsertLocally.map(\.id), [idB])
        XCTAssertEqual(plan.upload.map(\.id), [idA])
        XCTAssertTrue(plan.deleteLocally.isEmpty, "다른 날 글을 지우고 있습니다.")
        XCTAssertTrue(plan.deleteRemotely.isEmpty)
    }

    func testDifferentQuotesOnTheSameDayAreNeverMerged() {
        let a = note(idA, slug: "seneca-luck", updatedAt: morning)
        let b = note(idB, slug: "mlk-step", updatedAt: evening)

        let plan = JournalSync.plan(local: [a], remote: [b])

        XCTAssertTrue(plan.deleteLocally.isEmpty, "다른 명언에 쓴 글을 지우고 있습니다.")
        XCTAssertTrue(plan.deleteRemotely.isEmpty)
    }

    // MARK: - 순서

    /// 넣는 차례가 달라도 결과가 같아야 한다. 두 기기의 동의는 여기에 기댄다.
    func testTheOrderOfTheInputDoesNotChangeTheResult() {
        let a = note(idA, day: "2026-10-14", updatedAt: morning)
        let b = note(idB, day: "2026-10-15", updatedAt: evening)
        let c = note(idC, day: "2026-10-16", updatedAt: night)

        let one = JournalSync.plan(local: [], remote: [a, b, c])
        let other = JournalSync.plan(local: [], remote: [c, a, b])

        XCTAssertEqual(one.upsertLocally, other.upsertLocally)
    }
}
