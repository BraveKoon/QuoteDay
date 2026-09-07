import CloudKit
import Foundation

/// CloudKit 공개 데이터베이스로 하트를 주고받는다.
///
/// ## 왜 쿼리를 한 번도 쓰지 않는가
///
/// 레코드 이름을 값에서 **결정적으로** 만든다.
///
///     하트 하나  QuoteHeart       "<명언 slug>|<내 사용자 레코드 이름>"
///     합계        QuoteHeartTally  "tally|<명언 slug>"
///
/// 그래서 모든 읽기가 `records(for:)`(ID 로 가져오기)로 끝난다.
/// CloudKit 에서 쿼리를 쓰려면 대시보드에서 필드마다 인덱스를 켜 줘야 하는데,
/// 그 설정을 잊으면 앱은 빌드도 되고 실행도 되다가 **실기기에서만** 조용히 실패한다.
/// ID 로만 접근하면 그 함정이 통째로 사라진다.
///
/// 같은 이유로 한 사람이 같은 명언에 하트를 두 번 남길 수 없다 —
/// 레코드 이름이 같아서 두 번째 저장이 첫 번째를 덮어쓴다.
///
/// ## 합계의 정확도
///
/// CloudKit 에는 원자적 증가가 없다. 합계 레코드를 읽고 고쳐서 다시 쓰며,
/// 그 사이에 남이 먼저 쓰면 `serverRecordChanged` 가 오므로 다시 읽고 시도한다.
/// 동시에 누르는 사람이 아주 많으면 몇 개가 누락될 수 있다.
/// 하트 수에는 감당할 만한 오차이고, 그것을 없애려면 서버를 직접 두어야 한다.
/// `CKContainer` 는 스레드 안전하다고 문서에 적혀 있지만 `Sendable` 표시는 없다.
/// 저장하는 것이 그 하나뿐이라 `@unchecked` 로 명시한다.
struct CloudKitHeartService: HeartSyncing, @unchecked Sendable {

    private let container: CKContainer

    /// 컨테이너 식별자가 없으면 **아예 만들어지지 않는다.**
    ///
    /// `CKContainer` 를 엔타이틀먼트 없이 건드리면 앱이 죽을 수 있어서,
    /// 설정되지 않은 빌드에서는 이 타입의 인스턴스 자체가 생기지 않게 했다.
    /// (App Group 때도 같은 실수를 했다 — 객체는 멀쩡히 만들어지고 나중에 죽었다.)
    init?(containerIdentifier: String?) {
        guard let identifier = containerIdentifier?.trimmingCharacters(in: .whitespaces),
              !identifier.isEmpty
        else { return nil }
        self.container = CKContainer(identifier: identifier)
    }

    private var database: CKDatabase { container.publicCloudDatabase }

    // MARK: - 레코드 이름

    private enum RecordType {
        static let heart = "QuoteHeart"
        static let tally = "QuoteHeartTally"
    }

    private enum Field {
        static let quoteSlug = "quoteSlug"
        static let count = "count"
    }

    private static func tallyID(_ slug: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "tally|\(slug)")
    }

    private static func heartID(slug: String, user: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(slug)|\(user.recordName)")
    }

    // MARK: - 상태

    func availability() async -> HeartSyncAvailability {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .ready
            case .noAccount, .restricted:
                return .noAccount
            case .couldNotDetermine, .temporarilyUnavailable:
                return .failed("iCloud 상태를 확인하지 못했습니다.")
            @unknown default:
                return .failed("알 수 없는 iCloud 상태입니다.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - 읽기

    func counts(for slugs: [String]) async throws -> [String: Int] {
        var result: [String: Int] = [:]
        for chunk in slugs.chunked(into: Self.batchSize) {
            let ids = chunk.map(Self.tallyID)
            let fetched = try await database.records(for: ids)
            for (_, outcome) in fetched {
                // 아직 아무도 누르지 않은 명언은 레코드가 없다. 정상이다.
                guard let record = try? outcome.get() else { continue }
                guard let slug = record[Field.quoteSlug] as? String else { continue }
                result[slug] = Self.intValue(record[Field.count])
            }
        }
        return result
    }

    func myHearts(among slugs: [String]) async throws -> Set<String> {
        let user = try await container.userRecordID()
        var result: Set<String> = []
        for chunk in slugs.chunked(into: Self.batchSize) {
            let ids = chunk.map { Self.heartID(slug: $0, user: user) }
            let fetched = try await database.records(for: ids)
            for (_, outcome) in fetched {
                guard let record = try? outcome.get(),
                      let slug = record[Field.quoteSlug] as? String
                else { continue }
                result.insert(slug)
            }
        }
        return result
    }

    // MARK: - 쓰기

    @discardableResult
    func setHeart(_ isOn: Bool, slug: String) async throws -> Int {
        let user = try await container.userRecordID()
        let id = Self.heartID(slug: slug, user: user)

        // 이미 그 상태면 합계를 건드리지 않는다.
        // 같은 하트를 두 번 세는 일을 막는 유일한 방어선이다.
        let existed = (try? await database.record(for: id)) != nil
        guard existed != isOn else {
            return try await tally(slug: slug)
        }

        if isOn {
            let record = CKRecord(recordType: RecordType.heart, recordID: id)
            record[Field.quoteSlug] = slug
            _ = try await database.save(record)
        } else {
            _ = try await database.deleteRecord(withID: id)
        }

        return try await adjustTally(slug: slug, delta: isOn ? 1 : -1)
    }

    // MARK: - 합계

    private func tally(slug: String) async throws -> Int {
        guard let record = try? await database.record(for: Self.tallyID(slug)) else { return 0 }
        return Self.intValue(record[Field.count])
    }

    /// 합계를 읽고 고쳐 다시 쓴다. 남이 먼저 썼으면 다시 읽고 시도한다.
    private func adjustTally(slug: String, delta: Int) async throws -> Int {
        let id = Self.tallyID(slug)
        var lastError: Error?

        for _ in 0..<Self.tallyRetryLimit {
            let existing = try? await database.record(for: id)
            let record = existing ?? CKRecord(recordType: RecordType.tally, recordID: id)
            // 음수로 내려가지 않게 막는다. 어긋난 삭제가 있어도 화면이 이상해지지 않는다.
            let next = max(0, Self.intValue(record[Field.count]) + delta)

            record[Field.quoteSlug] = slug
            record[Field.count] = Int64(next)

            do {
                let saved = try await database.save(record)
                return Self.intValue(saved[Field.count])
            } catch let error as CKError where error.code == .serverRecordChanged {
                lastError = error
                continue
            }
        }
        throw lastError ?? CKError(.internalError)
    }

    // MARK: - 도우미

    /// 한 번에 가져오는 레코드 수. CloudKit 권장 상한 안쪽으로 둔다.
    private static let batchSize = 200
    private static let tallyRetryLimit = 4

    /// CloudKit 은 숫자를 NSNumber 로 돌려주므로 두 가지를 모두 받아 준다.
    private static func intValue(_ value: Any?) -> Int {
        if let number = value as? Int64 { return Int(number) }
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return 0
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, count > size else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
