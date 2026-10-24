import Foundation

/// 동기화가 한 번 돌 때 무엇을 할지 적어 둔 쪽지.
///
/// **적용 순서가 정해져 있다 — `upsertLocally` 를 먼저, `deleteLocally` 를 나중에.**
/// 거꾸로 하면 잃는 글이 생긴다. 중복을 합칠 때 진 쪽 글은 이긴 쪽 본문 안으로
/// 들어간 다음 지워지는데, 지우기를 먼저 적용하면 합쳐진 본문이 도착하기 전에
/// 원본이 사라지는 창이 열린다.
public struct JournalSyncPlan: Equatable, Sendable {
    /// 기기에 넣거나 덮어쓸 기록. **먼저 적용한다.**
    public let upsertLocally: [ArchivedNote]
    /// 기기에서 지울 기록. **나중에 적용한다.**
    public let deleteLocally: [UUID]
    /// 클라우드에 올릴 기록.
    public let upload: [ArchivedNote]
    /// 클라우드에서 지울 기록.
    public let deleteRemotely: [UUID]

    public init(
        upsertLocally: [ArchivedNote] = [],
        deleteLocally: [UUID] = [],
        upload: [ArchivedNote] = [],
        deleteRemotely: [UUID] = []
    ) {
        self.upsertLocally = upsertLocally
        self.deleteLocally = deleteLocally
        self.upload = upload
        self.deleteRemotely = deleteRemotely
    }

    public var isEmpty: Bool {
        upsertLocally.isEmpty && deleteLocally.isEmpty
            && upload.isEmpty && deleteRemotely.isEmpty
    }
}

/// 기기에 있는 것과 클라우드에 있는 것을 어떻게 합칠지 정한다.
///
/// ## 이 타입이 CloudKit 을 모르는 이유
///
/// CloudKit 은 시뮬레이터에서도 CI 에서도 검증되지 않는다. 그래서 **틀리면
/// 사용자 글이 사라지는 판단**을 전부 여기로 끌어내 순수 함수로 두고, 기기에서만
/// 돌아가는 쪽에는 레코드를 옮겨 담는 일만 남긴다. `JournalStreakRules` 와
/// `MonthlyReview` 가 같은 이유로 이렇게 되어 있다.
///
/// ## 두 기기가 같은 답을 내야 한다
///
/// 중복 병합은 **가진 글의 집합만 보고** 결정된다. 누가 먼저 켜졌는지, 어느
/// 쪽이 먼저 올렸는지는 보지 않는다. 그래서 두 기기가 따로 계산해도 같은 결과가
/// 나오고, 합쳐진 글이 서로를 덮어써도 내용이 흔들리지 않는다. 시각이 같아
/// 순서를 가릴 수 없을 때 `id` 문자열로 가르는 것도 그 때문이다 — 임의로
/// 고르면 두 기기가 다른 답을 낸다.
public enum JournalSync {

    /// 합쳐진 글에서 두 사람의 글을 가르는 줄.
    ///
    /// 사용자가 쓰지 않은 글자를 본문에 넣는 일이라 가볍게 정할 것이 아니지만,
    /// 둘 중 하나를 말없이 버리는 것보다는 낫다.
    public static let mergeSeparator = "\n\n———\n\n"

    /// 이번에 할 일을 정한다.
    ///
    /// - Parameters:
    ///   - local: 지금 기기에 있는 기록 전부.
    ///   - remote: 클라우드에서 받은 기록(바뀐 것만이어도 되고 전부여도 된다).
    ///   - remotelyDeleted: 클라우드에서 지워졌다고 통보받은 기록.
    ///   - pendingLocalDeletions: 기기에서 지웠지만 아직 올리지 못한 기록.
    ///     이게 없으면 **지운 글이 되살아난다** — 비행기 모드에서 지우고,
    ///     올리기 전에 받아 오면 클라우드에 남아 있는 원본이 그대로 돌아온다.
    public static func plan(
        local: [ArchivedNote],
        remote: [ArchivedNote],
        remotelyDeleted: Set<UUID> = [],
        pendingLocalDeletions: Set<UUID> = []
    ) -> JournalSyncPlan {
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var upsertLocally: [UUID: ArchivedNote] = [:]
        var deleteLocally: Set<UUID> = []
        var upload: [UUID: ArchivedNote] = [:]
        var deleteRemotely: Set<UUID> = []

        // 1. 저쪽에서 지운 것. 내가 지우는 중인 것은 어차피 사라지므로 건너뛴다.
        for id in remotelyDeleted
        where localByID[id] != nil && !pendingLocalDeletions.contains(id) {
            deleteLocally.insert(id)
        }

        // 2. 같은 id 를 맞대 본다.
        for note in remote {
            if pendingLocalDeletions.contains(note.id) {
                // 내가 지운 글이 아직 저쪽에 있다. 되살리지 않고 마저 지운다.
                deleteRemotely.insert(note.id)
                continue
            }
            // 같은 묶음에 삭제가 함께 왔으면 삭제가 이긴다.
            if remotelyDeleted.contains(note.id) { continue }

            guard let mine = localByID[note.id] else {
                upsertLocally[note.id] = note
                continue
            }
            if note.updatedAt > mine.updatedAt {
                upsertLocally[note.id] = note
            } else if mine.updatedAt > note.updatedAt {
                upload[mine.id] = mine
            }
            // 같으면 둘 다 건드리지 않는다. 쓸데없는 왕복을 만들지 않는다.
        }

        // 3. 저쪽에 아예 없는 내 글. 첫 동기화에서 전부 여기로 들어온다.
        for note in local
        where remoteByID[note.id] == nil
            && !remotelyDeleted.contains(note.id)
            && !pendingLocalDeletions.contains(note.id) {
            upload[note.id] = note
        }

        // 4. 위를 다 적용한 뒤의 모습에서 (날짜, 명언) 중복을 합친다.
        //    지금 가진 글이 아니라 **적용이 끝난 뒤의 글**을 봐야 한다.
        let keptHere = local
            .filter { !deleteLocally.contains($0.id) && !pendingLocalDeletions.contains($0.id) }
            .map { upsertLocally[$0.id] ?? $0 }
        let arriving = upsertLocally.values.filter { localByID[$0.id] == nil }
        let settled = keptHere + arriving

        for group in duplicateGroups(in: settled) {
            let merged = merge(group)
            upsertLocally[merged.id] = merged
            upload[merged.id] = merged
            for loser in group where loser.id != merged.id {
                deleteLocally.insert(loser.id)
                deleteRemotely.insert(loser.id)
                upsertLocally[loser.id] = nil
                upload[loser.id] = nil
            }
        }

        // 합쳐진 글을 지우라고 적어 두었을 리는 없지만, 적혀 있으면 글이 사라진다.
        deleteLocally.subtract(upsertLocally.keys)
        // 없는 글을 지우라고 시키지 않는다. 중복을 합칠 때 진 쪽은 저쪽 기기에만
        // 있을 수 있는데, 그걸 그대로 적어 두면 두 기기의 계획이 괜히 달라 보인다.
        deleteLocally.formIntersection(localByID.keys)

        return JournalSyncPlan(
            upsertLocally: orderedNotes(upsertLocally.values),
            deleteLocally: orderedIDs(deleteLocally),
            upload: orderedNotes(upload.values),
            deleteRemotely: orderedIDs(deleteRemotely)
        )
    }

    // MARK: - 중복

    /// `(dayKey, quoteSlug)` 가 겹치는 묶음만. 안이 둘 이상인 것만 돌려준다.
    ///
    /// 순서는 `id` 로 고정한다. 두 기기가 같은 답을 내야 하기 때문이다.
    static func duplicateGroups(in notes: [ArchivedNote]) -> [[ArchivedNote]] {
        var buckets: [String: [ArchivedNote]] = [:]
        for note in notes {
            // 명언 slug 에 구분자가 들어갈 일은 없지만, 들어가도 섞이지 않게 길이를 앞에 둔다.
            let key = "\(note.dayKey.count)|\(note.dayKey)|\(note.quoteSlug)"
            buckets[key, default: []].append(note)
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { orderedNotes($0) }
            .sorted { ($0.first?.id.uuidString ?? "") < ($1.first?.id.uuidString ?? "") }
    }

    /// 겹친 글을 한 편으로 합친다. **아무 글도 버리지 않는다.**
    ///
    /// 이긴 쪽은 `updatedAt` 이 늦은 쪽, 같으면 `id` 문자열이 작은 쪽이다.
    /// 진 쪽 본문은 구분선 뒤에 붙는다. 이미 들어 있으면 또 붙이지 않는다 —
    /// 이 함수가 두 번 돌아도 결과가 같아야 한다.
    static func merge(_ group: [ArchivedNote]) -> ArchivedNote {
        let ranked = group.sorted { left, right in
            if left.updatedAt != right.updatedAt { return left.updatedAt > right.updatedAt }
            return left.id.uuidString < right.id.uuidString
        }
        guard let winner = ranked.first else {
            preconditionFailure("빈 묶음은 duplicateGroups 가 걸러 낸다.")
        }

        var text = winner.text
        for loser in orderedNotes(ranked.dropFirst()) where !text.contains(loser.text) {
            text += mergeSeparator + loser.text
        }

        return ArchivedNote(
            id: winner.id,
            dayKey: winner.dayKey,
            quoteSlug: winner.quoteSlug,
            quoteText: winner.quoteText,
            authorName: winner.authorName,
            // 이긴 쪽이 기분을 안 골랐으면 진 쪽 것을 쓴다. 비우는 것보다 낫다.
            mood: winner.mood ?? orderedNotes(ranked.dropFirst()).compactMap(\.mood).first,
            source: winner.source,
            text: text,
            // 처음 쓴 시각은 가장 이른 것. "언제부터 썼나"가 뜻을 잃지 않게.
            createdAt: group.map(\.createdAt).min() ?? winner.createdAt,
            updatedAt: winner.updatedAt
        )
    }

    // MARK: - 순서

    /// 어디서 돌려도 같은 차례가 되게. 테스트도 두 기기도 여기에 기댄다.
    private static func orderedNotes<S: Sequence>(_ notes: S) -> [ArchivedNote]
    where S.Element == ArchivedNote {
        notes.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private static func orderedIDs<S: Sequence>(_ ids: S) -> [UUID] where S.Element == UUID {
        ids.sorted { $0.uuidString < $1.uuidString }
    }
}
