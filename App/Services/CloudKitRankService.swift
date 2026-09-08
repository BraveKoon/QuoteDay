import CloudKit
import Foundation

/// CloudKit 공개 데이터베이스로 챌린지 랭킹을 주고받는다.
///
/// ## 순위를 세는 방법
///
/// 사람마다 점수 레코드를 하나 두고 그것을 세어서 순위를 내려면 조건 검색이 필요한데,
/// CloudKit 의 조건 검색은 대시보드에서 필드마다 인덱스를 켜 줘야 한다.
/// 그 설정을 잊으면 앱은 빌드도 되고 실행도 되다가 **실기기에서만** 조용히 실패한다.
///
/// 그래서 점수 분포를 200점 구간으로 나눠 **구간마다 사람 수를 세어 둔다.**
///
///     내 점수    ChallengePlayerScore  "<내 사용자 레코드 이름>"
///     분포        ChallengeRankBucket   "rank-bucket|<구간 번호>"
///
/// 구간 레코드는 이름이 정해져 있으므로 ID 로 한 번에 가져올 수 있다.
/// 하트와 같은 원칙이고, 같은 이유다.
///
/// ## 정확도
///
/// 구간 수를 고칠 때도 원자적 증가가 없어서 읽고 고쳐 다시 쓴다.
/// 동시에 여러 사람이 같은 구간을 넘나들면 몇이 어긋날 수 있다.
/// 순위는 "상위 몇 %" 수준으로만 보여 주므로 감당할 만한 오차다.
struct CloudKitRankService: RankSyncing, @unchecked Sendable {

    private let container: CKContainer

    /// 컨테이너 식별자가 없으면 만들어지지 않는다.
    /// 엔타이틀먼트 없이 `CKContainer` 를 건드리면 프로세스가 죽기 때문이다.
    init?(containerIdentifier: String?) {
        guard let identifier = containerIdentifier?.trimmingCharacters(in: .whitespaces),
              !identifier.isEmpty
        else { return nil }
        self.container = CKContainer(identifier: identifier)
    }

    private var database: CKDatabase { container.publicCloudDatabase }

    private enum RecordType {
        static let score = "ChallengePlayerScore"
        static let bucket = "ChallengeRankBucket"
    }

    private enum Field {
        static let total = "total"
        static let bucket = "bucket"
        static let count = "count"
    }

    private static func bucketID(_ index: Int) -> CKRecord.ID {
        CKRecord.ID(recordName: "rank-bucket|\(index)")
    }

    // MARK: - 상태

    func availability() async -> CloudSyncAvailability {
        do {
            switch try await container.accountStatus() {
            case .available: return .ready
            case .noAccount, .restricted: return .noAccount
            case .couldNotDetermine, .temporarilyUnavailable:
                return .failed("iCloud 상태를 확인하지 못했습니다.")
            @unknown default: return .failed("알 수 없는 iCloud 상태입니다.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - 읽기

    func standing(total: Int) async throws -> RankStanding {
        RankStanding.from(counts: try await bucketCounts(), total: total)
    }

    private func bucketCounts() async throws -> [Int: Int] {
        let fetched = try await database.records(for: RankBucket.allIndices.map(Self.bucketID))
        var counts: [Int: Int] = [:]
        for (_, outcome) in fetched {
            // 아직 아무도 들어오지 않은 구간은 레코드가 없다. 정상이다.
            guard let record = try? outcome.get() else { continue }
            let index = Self.intValue(record[Field.bucket])
            counts[index, default: 0] += Self.intValue(record[Field.count])
        }
        return counts
    }

    // MARK: - 쓰기

    func submit(total: Int) async throws -> RankStanding {
        let me = try await container.userRecordID()
        let id = CKRecord.ID(recordName: me.recordName)
        let newBucket = RankBucket.index(for: total)

        let existing = try? await database.record(for: id)
        let oldBucket = existing.map { Self.intValue($0[Field.bucket]) }

        // 구간이 바뀔 때만 분포를 고친다. 같은 구간 안에서 점수만 오르면
        // 사람 수는 그대로이므로 건드릴 것이 없다.
        if oldBucket != newBucket {
            if let oldBucket {
                try await adjustBucket(oldBucket, delta: -1)
            }
            try await adjustBucket(newBucket, delta: 1)
        }

        let record = existing ?? CKRecord(recordType: RecordType.score, recordID: id)
        record[Field.total] = Int64(max(0, total))
        record[Field.bucket] = Int64(newBucket)
        _ = try? await database.save(record)

        return try await standing(total: total)
    }

    /// 구간의 사람 수를 고친다. 남이 먼저 썼으면 다시 읽고 시도한다.
    private func adjustBucket(_ index: Int, delta: Int) async throws {
        let id = Self.bucketID(index)
        var lastError: Error?

        for _ in 0..<Self.retryLimit {
            let existing = try? await database.record(for: id)
            let record = existing ?? CKRecord(recordType: RecordType.bucket, recordID: id)
            let next = max(0, Self.intValue(record[Field.count]) + delta)

            record[Field.bucket] = Int64(index)
            record[Field.count] = Int64(next)

            do {
                _ = try await database.save(record)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                lastError = error
                continue
            }
        }
        throw lastError ?? CKError(.internalError)
    }

    // MARK: - 도우미

    private static let retryLimit = 4

    private static func intValue(_ value: Any?) -> Int {
        if let number = value as? Int64 { return Int(number) }
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return 0
    }
}
